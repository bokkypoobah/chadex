pragma solidity ^0.5.0;

import "BokkyPooBahsRedBlackTreeLibrary.sol";

// ----------------------------------------------------------------------------
// Orders Data Structure
// ----------------------------------------------------------------------------
library Orders {
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
    struct Data {
        bool initialised;
        // PairKey (bytes32) => BuySell (OrderType) => Price (BPBRBTL)
        mapping(bytes32 => mapping(uint => BokkyPooBahsRedBlackTreeLibrary.Tree)) orderKeys;
        // PairKey (bytes32) => BuySell (OrderType) => Price (uint) => OrderKey (bytes32)
        mapping(bytes32 => mapping(uint => mapping(uint => OrderQueue))) orderQueue;
        // OrderKey (bytes32) => Order
        mapping(bytes32 => Order) orders;
        // Data => block.number when first seen
        mapping(address => uint) tokens;
        mapping(address => uint) accounts;
        mapping(bytes32 => uint) pairs;
    }

    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);

    bytes32 private constant ORDERKEY_SENTINEL = 0x0;
    uint private constant PRICEKEY_SENTINEL = 0;

    event OrderAdded(bytes32 indexed pairKey, bytes32 indexed key, uint orderType, address indexed maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens);
    event OrderRemoved(bytes32 indexed key);
    event OrderUpdated(bytes32 indexed key, uint baseTokens, uint newBaseTokens);

    function init(Data storage self) internal {
        require(!self.initialised);
        self.initialised = true;
    }
    function pairKey(address baseToken, address quoteToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseToken, quoteToken));
    }
    function orderKey(OrderType orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderType, maker, baseToken, quoteToken, price, expiry));
    }
    function exists(Data storage self, bytes32 key) internal view returns (bool) {
        return self.orders[key].baseToken != address(0);
    }
    function inverseOrderType(OrderType orderType) internal pure returns (OrderType) {
        return (orderType == OrderType.BUY) ? OrderType.SELL : OrderType.BUY;
    }

    function addToken(Data storage self, address token) internal {
        if (self.tokens[token] == 0) {
            self.tokens[token] = block.number;
            emit TokenAdded(token);
        }
    }
    function addAccount(Data storage self, address account) internal {
        if (self.accounts[account] == 0) {
            self.accounts[account] = block.number;
            emit AccountAdded(account);
        }
    }
    function addPair(Data storage self, bytes32 _pairKey, address baseToken, address quoteToken) internal {
        if (self.pairs[_pairKey] == 0) {
            self.pairs[_pairKey] = block.number;
            emit PairAdded(_pairKey, baseToken, quoteToken);
        }
    }

    function getBestMatchingOrder(Data storage self, OrderType orderType, address baseToken, address quoteToken, uint price) public returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        OrderType _inverseOrderType = inverseOrderType(orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = self.orderKeys[_pairKey][uint(_inverseOrderType)];
        if (keys.initialised) {
            emit LogInfo("getBestMatchingOrder: keys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (orderType == OrderType.BUY) ? keys.first() : keys.last();
            // bool priceCheck = (priceKey == PRICEKEY_SENTINEL) ? false : (orderType == OrderType.BUY) ? priceKey <= price : priceKey >= price;
            // priceCheck = true;
            // while (priceCheck && priceKey != PRICEKEY_SENTINEL) {
            while (priceKey != PRICEKEY_SENTINEL) {
                emit LogInfo("getBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
                if (orderQueue.exists) {
                    emit LogInfo("getBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));
                    _orderKey = orderQueue.head;
                    while (_orderKey != ORDERKEY_SENTINEL) {
                        Order storage order = self.orders[_orderKey];
                        emit LogInfo("getBestMatchingOrder: _orderKey ", order.expiry, _orderKey, "", address(0));
                        if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                            return _orderKey;
                        }
                        _orderKey = self.orders[_orderKey].next;
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
    function updateBestMatchingOrder(Data storage self, OrderType orderType, address baseToken, address quoteToken, uint price, bytes32 matchingOrderKey) public returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        OrderType _inverseOrderType = inverseOrderType(orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = self.orderKeys[_pairKey][uint(_inverseOrderType)];
        if (keys.initialised) {
            emit LogInfo("updateBestMatchingOrder: keys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (orderType == OrderType.BUY) ? keys.first() : keys.last();
            while (priceKey != PRICEKEY_SENTINEL) {
                emit LogInfo("updateBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
                if (orderQueue.exists) {
                    emit LogInfo("updateBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));

                    Order storage order = self.orders[matchingOrderKey];
                    // TODO: What happens when allowance or balance is lower than #baseTokens
                    if (order.baseTokens == order.baseTokensFilled) {
                        orderQueue.head = order.next;
                        if (order.next != ORDERKEY_SENTINEL) {
                            self.orders[order.next].prev = ORDERKEY_SENTINEL;
                        }
                        order.prev = ORDERKEY_SENTINEL;
                        if (orderQueue.tail == matchingOrderKey) {
                            orderQueue.tail = ORDERKEY_SENTINEL;
                        }
                        delete self.orders[matchingOrderKey];
                    // Else update head to current if not (skipped expired)
                    } else {
                        if (orderQueue.head != matchingOrderKey) {
                            orderQueue.head = matchingOrderKey;
                        }
                    }
                    // TODO: Clear out queue info, and prie tree if necessary
                    if (orderQueue.head == ORDERKEY_SENTINEL) {
                        delete self.orderQueue[_pairKey][uint(_inverseOrderType)][priceKey];
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
    function add(Data storage self, OrderType orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens) public returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        _orderKey = orderKey(orderType, maker, baseToken, quoteToken, price, expiry);
        require(self.orders[_orderKey].maker == address(0));

        addToken(self, baseToken);
        addToken(self, quoteToken);
        addAccount(self, maker);
        addPair(self, _pairKey, baseToken, quoteToken);

        BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = self.orderKeys[_pairKey][uint(orderType)];
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

        OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(orderType)][price];
        if (!orderQueue.exists) {
            self.orderQueue[_pairKey][uint(orderType)][price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            orderQueue = self.orderQueue[_pairKey][uint(orderType)][price];
        }
        // Above - new 179,681, existing 36,234

        if (orderQueue.tail == ORDERKEY_SENTINEL) {
            orderQueue.head = _orderKey;
            orderQueue.tail = _orderKey;
            self.orders[_orderKey] = Order(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL, orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            emit LogInfo("orders addData  first", 0, _orderKey, "", address(0));
        } else {
            self.orders[orderQueue.tail].next = _orderKey;
            self.orders[_orderKey] = Order(orderQueue.tail, ORDERKEY_SENTINEL, orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            orderQueue.tail = _orderKey;
            emit LogInfo("orders addData !first", 0, _orderKey, "", address(0));
        }
        // Above saving prev and next - new 232,985, existing 84,961
        // Above saving all - new 385,258, existing 241,975

        emit OrderAdded(_pairKey, _orderKey, uint(orderType), maker, baseToken, quoteToken, price, expiry, baseTokens);
    }
    function remove(Data storage self, bytes32 _orderKey, address msgSender) public {
        require(_orderKey != ORDERKEY_SENTINEL);
        Order memory order = self.orders[_orderKey];
        require(order.maker == msgSender);

        bytes32 _pairKey = pairKey(order.baseToken, order.quoteToken);
        OrderQueue storage orderQueue = self.orderQueue[_pairKey][uint(order.orderType)][order.price];
        require(orderQueue.exists);

        OrderType orderType = order.orderType;
        uint price = order.price;

        // Only order
        if (orderQueue.head == _orderKey && orderQueue.tail == _orderKey) {
            orderQueue.head = ORDERKEY_SENTINEL;
            orderQueue.tail = ORDERKEY_SENTINEL;
            delete self.orders[_orderKey];
        // First item
        } else if (orderQueue.head == _orderKey) {
            bytes32 next = self.orders[_orderKey].next;
            self.orders[next].prev = ORDERKEY_SENTINEL;
            orderQueue.head = next;
            delete self.orders[_orderKey];
        // Last item
        } else if (orderQueue.tail == _orderKey) {
            bytes32 prev = self.orders[_orderKey].prev;
            self.orders[prev].next = ORDERKEY_SENTINEL;
            orderQueue.tail = prev;
            delete self.orders[_orderKey];
        // Item in the middle
        } else {
            bytes32 prev = self.orders[_orderKey].prev;
            bytes32 next = self.orders[_orderKey].next;
            self.orders[prev].next = ORDERKEY_SENTINEL;
            self.orders[next].prev = prev;
            delete self.orders[_orderKey];
        }
        emit OrderRemoved(_orderKey);
        if (orderQueue.head == ORDERKEY_SENTINEL && orderQueue.tail == ORDERKEY_SENTINEL) {
            delete self.orderQueue[_pairKey][uint(orderType)][price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage keys = self.orderKeys[_pairKey][uint(orderType)];
            if (keys.exists(price)) {
                keys.remove(price);
                emit LogInfo("orders remove RBT", price, 0x0, "", address(0));
            }
        }
    }
}
