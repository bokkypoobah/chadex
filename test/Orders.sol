pragma solidity ^0.5.0;

import "BokkyPooBahsRedBlackTreeLibrary.sol";
import "DexzBase.sol";

// ----------------------------------------------------------------------------
// Orders Data Structure
// ----------------------------------------------------------------------------
contract Orders is DexzBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    // Note that the BUY and SELL flags are used as indices
    uint constant public ORDERTYPE_BUY = 0x00;
    uint constant public ORDERTYPE_SELL = 0x01;
    uint constant public ORDERFLAG_BUYSELL = 0x01;
    uint constant public ORDERFLAG_ADDORDER = 0x10;

    // TODO FillMax, FillOrRevert,

    // 0.00054087 = new BigNumber(54087).shift(10);
    // GNT/ETH = base/quote = 0.00054087
    struct Order {
        bytes32 prev;
        bytes32 next;
        uint orderType;
        address maker;
        address baseToken;      // GNT
        address quoteToken;     // ETH
        uint price;             // GNT/ETH = 0.00054087 = #quoteToken per unit baseToken
        uint expiry;
        uint baseTokens;        // GNT - baseToken
        uint baseTokensFilled;
    }
    struct OrderQueue {
        bool exists;
        bytes32 head;
        bytes32 tail;
    }

    // PairKey (bytes32) => BuySell (uint) => Price (BPBRBTL)
    mapping(bytes32 => mapping(uint => BokkyPooBahsRedBlackTreeLibrary.Tree)) orderKeys;
    // PairKey (bytes32) => BuySell (uint) => Price (uint) => OrderQueue
    mapping(bytes32 => mapping(uint => mapping(uint => OrderQueue))) orderQueue;
    // OrderKey (bytes32) => Order
    mapping(bytes32 => Order) orders;

    bytes32 public constant ORDERKEY_SENTINEL = 0x0;
    uint private constant PRICEKEY_SENTINEL = 0;

    event OrderAdded(bytes32 indexed pairKey, bytes32 indexed key, uint orderType, address indexed maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens);
    event OrderRemoved(bytes32 indexed key);
    event OrderUpdated(bytes32 indexed key, uint baseTokens, uint newBaseTokens);


    constructor(address _feeAccount) public DexzBase(_feeAccount) {
    }


    // Price tree navigating
    function count(bytes32 _pairKey, uint _orderType) public view returns (uint _count) {
        _count = orderKeys[_pairKey][_orderType].count();
    }
    function first(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][_orderType].first();
    }
    function last(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][_orderType].last();
    }
    function next(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        _y = orderKeys[_pairKey][_orderType].next(_x);
    }
    function prev(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        _y = orderKeys[_pairKey][_orderType].prev(_x);
    }
    function exists(bytes32 _pairKey, uint _orderType, uint _key) public view returns (bool) {
        return orderKeys[_pairKey][_orderType].exists(_key);
    }
    function getNode(bytes32 _pairKey, uint _orderType, uint _key) public view returns (uint _returnKey, uint _parent, uint _left, uint _right, bool _red) {
        return orderKeys[_pairKey][_orderType].getNode(_key);
    }
    // Don't need parent, grandparent, sibling, uncle


    // Orders navigating
    function pairKey(address _baseToken, address _quoteToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_baseToken, _quoteToken));
    }
    function orderKey(uint _orderType, address _maker, address _baseToken, address _quoteToken, uint _price, uint _expiry) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_orderType, _maker, _baseToken, _quoteToken, _price, _expiry));
    }
    function exists(bytes32 _key) internal view returns (bool) {
        return orders[_key].baseToken != address(0);
    }
    function inverseOrderType(uint _orderType) internal pure returns (uint) {
        return (_orderType == ORDERTYPE_BUY) ? ORDERTYPE_SELL : ORDERTYPE_BUY;
    }


    function getBestPrice(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].last() : orderKeys[_pairKey][_orderType].first();
    }
    function getNextBestPrice(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isSentinel(_x)) {
            _y = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].last() : orderKeys[_pairKey][_orderType].first();
        } else {
            _y = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].prev(_x) : orderKeys[_pairKey][_orderType].next(_x);
        }
    }

    function getOrderQueue(bytes32 _pairKey, uint _orderType, uint _price) public view returns (bool _exists, bytes32 _head, bytes32 _tail) {
        Orders.OrderQueue memory _orderQueue = orderQueue[_pairKey][_orderType][_price];
        return (_orderQueue.exists, _orderQueue.head, _orderQueue.tail);
    }
    function getOrder(bytes32 _orderKey) public view returns (bytes32 _prev, bytes32 _next, uint _orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, uint baseTokensFilled) {
        Orders.Order memory order = orders[_orderKey];
        return (order.prev, order.next, order.orderType, order.maker, order.baseToken, order.quoteToken, order.price, order.expiry, order.baseTokens, order.baseTokensFilled);
    }


    function _getBestMatchingOrder(uint _orderType, address baseToken, address quoteToken, uint price) internal returns (uint _bestMatchingPriceKey, bytes32 _bestMatchingOrderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        uint _matchingOrderType = inverseOrderType(_orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_matchingOrderType];
        if (priceKeys.initialised) {
            emit LogInfo("getBestMatchingOrder: priceKeys.initialised", 0, 0x0, "", address(0));
            _bestMatchingPriceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.first() : priceKeys.last();
            bool priceOk = (_bestMatchingPriceKey == PRICEKEY_SENTINEL) ? false : (_orderType == ORDERTYPE_BUY) ? _bestMatchingPriceKey <= price : _bestMatchingPriceKey >= price;
            while (priceOk) {
                emit LogInfo("getBestMatchingOrder: _bestMatchingPriceKey", _bestMatchingPriceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][_matchingOrderType][_bestMatchingPriceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("getBestMatchingOrder: orderQueue not empty", _bestMatchingPriceKey, 0x0, "", address(0));
                    _bestMatchingOrderKey = _orderQueue.head;
                    while (_bestMatchingOrderKey != ORDERKEY_SENTINEL) {
                        Order storage order = orders[_bestMatchingOrderKey];
                        emit LogInfo("getBestMatchingOrder: _bestMatchingOrderKey ", order.expiry, _bestMatchingOrderKey, "", address(0));
                        if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                            return (_bestMatchingPriceKey, _bestMatchingOrderKey);
                        }
                        _bestMatchingOrderKey = orders[_bestMatchingOrderKey].next;
                    }
                } else {
                    // TODO: REMOVE _bestMatchingPriceKey
                    emit LogInfo("getBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                _bestMatchingPriceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.next(_bestMatchingPriceKey) : priceKeys.prev(_bestMatchingPriceKey);
                priceOk = (_bestMatchingPriceKey == PRICEKEY_SENTINEL) ? false : (_orderType == ORDERTYPE_BUY) ? _bestMatchingPriceKey <= price : _bestMatchingPriceKey >= price;
            }
            // OrderQueue storage orderQueue = self.orderQueue[_pairKey][_orderType][price];
        }
        return (PRICEKEY_SENTINEL, ORDERKEY_SENTINEL);
    }
    function _updateBestMatchingOrder(uint _orderType, address baseToken, address quoteToken, uint matchingPriceKey, bytes32 matchingOrderKey, bool _orderFilled) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        uint _matchingOrderType = inverseOrderType(_orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_matchingOrderType];
        if (priceKeys.initialised) {
            emit LogInfo("updateBestMatchingOrder: priceKeys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.first() : priceKeys.last();
            while (priceKey != PRICEKEY_SENTINEL) {
                emit LogInfo("updateBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][_matchingOrderType][priceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("updateBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));

                    Order storage order = orders[matchingOrderKey];
                    // TODO: What happens when allowance or balance is lower than #baseTokens
                    if (_orderFilled) {
                        _orderQueue.head = order.next;
                        if (order.next != ORDERKEY_SENTINEL) {
                            orders[order.next].prev = ORDERKEY_SENTINEL;
                        }
                        order.prev = ORDERKEY_SENTINEL;
                        if (_orderQueue.tail == matchingOrderKey) {
                            _orderQueue.tail = ORDERKEY_SENTINEL;
                        }
                        delete orders[matchingOrderKey];
                    // Else update head to current if not (skipped expired)
                    } else {
                        if (_orderQueue.head != matchingOrderKey) {
                            _orderQueue.head = matchingOrderKey;
                        }
                    }
                    // Clear out queue info, and prie tree if necessary
                    if (_orderQueue.head == ORDERKEY_SENTINEL) {
                        delete orderQueue[_pairKey][_matchingOrderType][priceKey];
                        priceKeys.remove(priceKey);
                        emit LogInfo("orders remove RBT", priceKey, 0x0, "", address(0));
                    }
                } else {
                    priceKeys.remove(priceKey);
                    emit LogInfo("updateBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                priceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.next(priceKey) : priceKeys.prev(priceKey);
            }
        }
        return ORDERKEY_SENTINEL;
    }
    function _addOrder(uint _orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        _orderKey = orderKey(_orderType, maker, baseToken, quoteToken, price, expiry);
        require(orders[_orderKey].maker == address(0));

        addToken(baseToken);
        addToken(quoteToken);
        addAccount(maker);
        addPair(_pairKey, baseToken, quoteToken);

        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_orderType];
        if (!priceKeys.initialised) {
            priceKeys.init();
        }
        if (!priceKeys.exists(price)) {
            priceKeys.insert(price);
            emit LogInfo("orders addKey RBT adding ", price, 0x0, "", address(0));
        } else {
            emit LogInfo("orders addKey RBT exists ", price, 0x0, "", address(0));
        }
        // Above - new 148,521, existing 35,723

        OrderQueue storage _orderQueue = orderQueue[_pairKey][_orderType][price];
        if (!_orderQueue.exists) {
            orderQueue[_pairKey][_orderType][price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            _orderQueue = orderQueue[_pairKey][_orderType][price];
        }
        // Above - new 179,681, existing 36,234

        if (_orderQueue.tail == ORDERKEY_SENTINEL) {
            _orderQueue.head = _orderKey;
            _orderQueue.tail = _orderKey;
            orders[_orderKey] = Order(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            emit LogInfo("orders addData  first", 0, _orderKey, "", address(0));
        } else {
            orders[_orderQueue.tail].next = _orderKey;
            orders[_orderKey] = Order(_orderQueue.tail, ORDERKEY_SENTINEL, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            _orderQueue.tail = _orderKey;
            emit LogInfo("orders addData !first", 0, _orderKey, "", address(0));
        }
        // Above saving prev and next - new 232,985, existing 84,961
        // Above saving all - new 385,258, existing 241,975

        emit OrderAdded(_pairKey, _orderKey, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens);
    }
    function _removeOrder(bytes32 _orderKey, address msgSender) internal {
        require(_orderKey != ORDERKEY_SENTINEL);
        Order memory order = orders[_orderKey];
        require(order.maker == msgSender);

        bytes32 _pairKey = pairKey(order.baseToken, order.quoteToken);
        OrderQueue storage _orderQueue = orderQueue[_pairKey][order.orderType][order.price];
        require(_orderQueue.exists);

        uint _orderType = order.orderType;
        uint _price = order.price;

        // Only order
        if (_orderQueue.head == _orderKey && _orderQueue.tail == _orderKey) {
            _orderQueue.head = ORDERKEY_SENTINEL;
            _orderQueue.tail = ORDERKEY_SENTINEL;
            delete orders[_orderKey];
        // First item
        } else if (_orderQueue.head == _orderKey) {
            bytes32 _next = orders[_orderKey].next;
            orders[_next].prev = ORDERKEY_SENTINEL;
            _orderQueue.head = _next;
            delete orders[_orderKey];
        // Last item
        } else if (_orderQueue.tail == _orderKey) {
            bytes32 _prev = orders[_orderKey].prev;
            orders[_prev].next = ORDERKEY_SENTINEL;
            _orderQueue.tail = _prev;
            delete orders[_orderKey];
        // Item in the middle
        } else {
            bytes32 _prev = orders[_orderKey].prev;
            bytes32 _next = orders[_orderKey].next;
            orders[_prev].next = ORDERKEY_SENTINEL;
            orders[_next].prev = _prev;
            delete orders[_orderKey];
        }
        emit OrderRemoved(_orderKey);
        if (_orderQueue.head == ORDERKEY_SENTINEL && _orderQueue.tail == ORDERKEY_SENTINEL) {
            delete orderQueue[_pairKey][_orderType][_price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_orderType];
            if (priceKeys.exists(_price)) {
                priceKeys.remove(_price);
                emit LogInfo("orders remove RBT", _price, 0x0, "", address(0));
            }
        }
    }
}
