pragma solidity ^0.5.0;

import "BokkyPooBahsRedBlackTreeLibrary.sol";
import "DexzBase.sol";

// ----------------------------------------------------------------------------
// Orders Data Structure
// ----------------------------------------------------------------------------
contract Orders is DexzBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    enum OrderType {
        BUY,
        SELL
    }

    // TODO FillMax, FillOrRevert,

    // 0.00054087 = new BigNumber(54087).shift(10);
    // GNT/ETH = base/quote = 0.00054087
    struct Order {
        bytes32 prev;
        bytes32 next;
        OrderType orderType;
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

    // PairKey (bytes32) => BuySell (OrderType) => Price (BPBRBTL)
    mapping(bytes32 => mapping(uint => BokkyPooBahsRedBlackTreeLibrary.Tree)) orderKeys;
    // PairKey (bytes32) => BuySell (OrderType) => Price (uint) => OrderQueue
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
    function count(bytes32 _pairKey, uint orderType) public view returns (uint _count) {
        _count = orderKeys[_pairKey][orderType].count();
    }
    function first(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][orderType].first();
    }
    function last(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][orderType].last();
    }
    function next(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        y = orderKeys[_pairKey][orderType].next(x);
    }
    function prev(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        y = orderKeys[_pairKey][orderType].prev(x);
    }
    function exists(bytes32 _pairKey, uint orderType, uint key) public view returns (bool) {
        return orderKeys[_pairKey][orderType].exists(key);
    }
    function getNode(bytes32 _pairKey, uint orderType, uint key) public view returns (uint _returnKey, uint _parent, uint _left, uint _right, bool _red) {
        return orderKeys[_pairKey][orderType].getNode(key);
    }
    // Don't need parent, grandparent, sibling, uncle


    // Orders navigating
    function pairKey(address baseToken, address quoteToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseToken, quoteToken));
    }
    function orderKey(OrderType orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderType, maker, baseToken, quoteToken, price, expiry));
    }
    function exists(bytes32 key) internal view returns (bool) {
        return orders[key].baseToken != address(0);
    }
    function inverseOrderType(OrderType orderType) internal pure returns (OrderType) {
        return (orderType == OrderType.BUY) ? OrderType.SELL : OrderType.BUY;
    }


    function getBestPrice(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        if (orderType == uint(Orders.OrderType.BUY)) {
            _key = orderKeys[_pairKey][orderType].last();
        } else {
            _key = orderKeys[_pairKey][orderType].first();
        }
    }
    function getNextBestPrice(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        if (orderType == uint(Orders.OrderType.BUY)) {
            if (BokkyPooBahsRedBlackTreeLibrary.isSentinel(x)) {
                y = orderKeys[_pairKey][orderType].last();
            } else {
                y = orderKeys[_pairKey][orderType].prev(x);
            }
        } else {
            if (BokkyPooBahsRedBlackTreeLibrary.isSentinel(x)) {
                y = orderKeys[_pairKey][orderType].first();
            } else {
                y = orderKeys[_pairKey][orderType].next(x);
            }
        }
    }

    function getOrderQueue(bytes32 _pairKey, uint orderType, uint price) public view returns (bool _exists, bytes32 _head, bytes32 _tail) {
        Orders.OrderQueue memory _orderQueue = orderQueue[_pairKey][uint(orderType)][price];
        return (_orderQueue.exists, _orderQueue.head, _orderQueue.tail);
    }
    function getOrder(bytes32 _orderKey) public view returns (bytes32 _prev, bytes32 _next, uint orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, uint baseTokensFilled) {
        Orders.Order memory order = orders[_orderKey];
        return (order.prev, order.next, uint(order.orderType), order.maker, order.baseToken, order.quoteToken, order.price, order.expiry, order.baseTokens, order.baseTokensFilled);
    }


    function _getBestMatchingOrder(OrderType orderType, address baseToken, address quoteToken, uint price) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        OrderType _inverseOrderType = inverseOrderType(orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = orderKeys[_pairKey][uint(_inverseOrderType)];
        if (keys.initialised) {
            emit LogInfo("getBestMatchingOrder: keys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (orderType == OrderType.BUY) ? keys.first() : keys.last();
            // bool priceCheck = (priceKey == PRICEKEY_SENTINEL) ? false : (orderType == OrderType.BUY) ? priceKey <= price : priceKey >= price;
            // priceCheck = true;
            // while (priceCheck && priceKey != PRICEKEY_SENTINEL) {
            while (priceKey != PRICEKEY_SENTINEL) {
                emit LogInfo("getBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("getBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));
                    _orderKey = _orderQueue.head;
                    while (_orderKey != ORDERKEY_SENTINEL) {
                        Order storage order = orders[_orderKey];
                        emit LogInfo("getBestMatchingOrder: _orderKey ", order.expiry, _orderKey, "", address(0));
                        if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                            return _orderKey;
                        }
                        _orderKey = orders[_orderKey].next;
                    }
                } else {
                    // TODO: REMOVE priceKey
                    emit LogInfo("getBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                priceKey = (orderType == OrderType.BUY) ? keys.next(priceKey) : keys.prev(priceKey);
            }
            // OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(orderType)][price];
        }
        return ORDERKEY_SENTINEL;
    }
    function _updateBestMatchingOrder(OrderType orderType, address baseToken, address quoteToken, uint price, bytes32 matchingOrderKey) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        OrderType _inverseOrderType = inverseOrderType(orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = orderKeys[_pairKey][uint(_inverseOrderType)];
        if (keys.initialised) {
            emit LogInfo("updateBestMatchingOrder: keys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (orderType == OrderType.BUY) ? keys.first() : keys.last();
            while (priceKey != PRICEKEY_SENTINEL) {
                emit LogInfo("updateBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("updateBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));

                    Order storage order = orders[matchingOrderKey];
                    // TODO: What happens when allowance or balance is lower than #baseTokens
                    if (order.baseTokens == order.baseTokensFilled) {
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
                    // TODO: Clear out queue info, and prie tree if necessary
                    if (_orderQueue.head == ORDERKEY_SENTINEL) {
                        delete orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
                        keys.remove(priceKey);
                        emit LogInfo("orders remove RBT", priceKey, 0x0, "", address(0));
                    }
                } else {
                    // TODO: REMOVE priceKey
                    emit LogInfo("updateBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                priceKey = (orderType == OrderType.BUY) ? keys.next(priceKey) : keys.prev(priceKey);
            }
            // OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(orderType)][price];
        }
        return ORDERKEY_SENTINEL;
    }
    function _addOrder(OrderType orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        _orderKey = orderKey(orderType, maker, baseToken, quoteToken, price, expiry);
        require(orders[_orderKey].maker == address(0));

        addToken(baseToken);
        addToken(quoteToken);
        addAccount(maker);
        addPair(_pairKey, baseToken, quoteToken);

        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = orderKeys[_pairKey][uint(orderType)];
        if (!keys.initialised) {
            keys.init();
        }
        if (!keys.exists(price)) {
            keys.insert(price);
            emit LogInfo("orders addKey RBT adding ", price, 0x0, "", address(0));
        } else {
            emit LogInfo("orders addKey RBT exists ", price, 0x0, "", address(0));
        }
        // Above - new 148,521, existing 35,723

        OrderQueue storage _orderQueue = orderQueue[_pairKey][uint(orderType)][price];
        if (!_orderQueue.exists) {
            orderQueue[_pairKey][uint(orderType)][price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            _orderQueue = orderQueue[_pairKey][uint(orderType)][price];
        }
        // Above - new 179,681, existing 36,234

        if (_orderQueue.tail == ORDERKEY_SENTINEL) {
            _orderQueue.head = _orderKey;
            _orderQueue.tail = _orderKey;
            orders[_orderKey] = Order(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL, orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            emit LogInfo("orders addData  first", 0, _orderKey, "", address(0));
        } else {
            orders[_orderQueue.tail].next = _orderKey;
            orders[_orderKey] = Order(_orderQueue.tail, ORDERKEY_SENTINEL, orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            _orderQueue.tail = _orderKey;
            emit LogInfo("orders addData !first", 0, _orderKey, "", address(0));
        }
        // Above saving prev and next - new 232,985, existing 84,961
        // Above saving all - new 385,258, existing 241,975

        emit OrderAdded(_pairKey, _orderKey, uint(orderType), maker, baseToken, quoteToken, price, expiry, baseTokens);
    }
    function _removeOrder(bytes32 _orderKey, address msgSender) internal {
        require(_orderKey != ORDERKEY_SENTINEL);
        Order memory order = orders[_orderKey];
        require(order.maker == msgSender);

        bytes32 _pairKey = pairKey(order.baseToken, order.quoteToken);
        OrderQueue storage _orderQueue = orderQueue[_pairKey][uint(order.orderType)][order.price];
        require(_orderQueue.exists);

        OrderType orderType = order.orderType;
        uint price = order.price;

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
            delete orderQueue[_pairKey][uint(orderType)][price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = orderKeys[_pairKey][uint(orderType)];
            if (keys.exists(price)) {
                keys.remove(price);
                emit LogInfo("orders remove RBT", price, 0x0, "", address(0));
            }
        }
    }
}
