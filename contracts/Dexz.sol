pragma solidity ^0.8.0;

// ----------------------------------------------------------------------------
// Dexz🤖, pronounced dex-zee, the token exchanger bot
//
// STATUS: In Development
//
// https://github.com/bokkypoobah/Dexz
//
// SPDX-License-Identifier: MIT
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

import "./BokkyPooBahsRedBlackTreeLibrary.sol";
import "hardhat/console.sol";


interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
}


contract ReentrancyGuard {
    uint private _executing;

    error ReentrancyAttempted();

    modifier reentrancyGuard() {
        if (_executing == 1) {
            revert ReentrancyAttempted();
        }
        _executing = 1;
        _;
        _executing = 2;
    }
}


contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
    function transferOwnershipImmediately(address _newOwner) public onlyOwner {
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

type PairKey is bytes32;
type OrderKey is bytes32;

// ----------------------------------------------------------------------------
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase is Owned {
    uint constant public TENPOW9 = uint(10)**9;
    uint constant public TENPOW18 = uint(10)**18;

    Price public constant PRICE_MIN = Price.wrap(1);
    Price public constant PRICE_MAX = Price.wrap(999_999_999_999_999_999); // max(uint64)=18,446,744,073,709,551,616

    uint public takerFeeInEthers = 0; // TODO 5 * 10 ** 16; // 0.05 ETH
    uint public takerFeeInTokens = 0; // TODO 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    struct Pair {
        address baseToken;
        address quoteToken;
        uint8 baseDecimals;
        uint8 quoteDecimals;
    }

    mapping(PairKey => Pair) public pairs;
    PairKey[] public pairKeys;

    event TakerFeeInEthersUpdated(uint oldTakerFeeInEthers, uint newTakerFeeInEthers);
    event TakerFeeInTokensUpdated(uint oldTakerFeeInTokens, uint newTakerFeeInTokens);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);
    event PairAdded(PairKey indexed pairKey, address indexed baseToken, address indexed quoteToken, uint8 baseDecimals, uint8 quoteDecimals);
    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);

    constructor(address _feeAccount) Owned() {
        feeAccount = _feeAccount;
    }

    function setTakerFeeInEthers(uint _takerFeeInEthers) public onlyOwner {
        emit TakerFeeInEthersUpdated(takerFeeInEthers, _takerFeeInEthers);
        takerFeeInEthers = _takerFeeInEthers;
    }
    function setTakerFeeInTokens(uint _takerFeeInTokens) public onlyOwner {
        emit TakerFeeInTokensUpdated(takerFeeInTokens, _takerFeeInTokens);
        takerFeeInTokens = _takerFeeInTokens;
    }
    function setFeeAccount(address _feeAccount) public onlyOwner {
        emit FeeAccountUpdated(feeAccount, _feeAccount);
        feeAccount = _feeAccount;
    }
    function pair(uint i) public view returns (PairKey pairKey, address baseToken, address quoteToken) {
        pairKey = pairKeys[i];
        Pair memory _pair = pairs[pairKey];
        return (pairKey, _pair.baseToken, _pair.quoteToken);
    }
    function pairsLength() public view returns (uint) {
        return pairKeys.length;
    }
    function addPair(PairKey pairKey, address baseToken, address quoteToken) internal {
        if (pairs[pairKey].baseToken == address(0)) {
            uint8 baseDecimals = IERC20(baseToken).decimals();
            uint8 quoteDecimals = IERC20(quoteToken).decimals();
            pairs[pairKey] = Pair(baseToken, quoteToken, baseDecimals, quoteDecimals);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, baseToken, quoteToken, baseDecimals, quoteDecimals);
        }
    }
    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        uint _allowance = IERC20(token).allowance(wallet, address(this));
        uint _balance = IERC20(token).balanceOf(wallet);
        _tokens = _allowance < _balance ? _allowance : _balance;
    }

    error TransferFromFailedApproval(address token, address from, address to, uint _tokens, uint _approved);
    error TransferFromFailed(address token, address from, address to, uint _tokens);

    function transferFrom(address token, address from, address to, uint _tokens) internal {
        // TODO: Remove check?
        // uint balanceToBefore = IERC20(token).balanceOf(to);
        // require(IERC20(token).transferFrom(from, to, _tokens));
        // uint balanceToAfter = IERC20(token).balanceOf(to);
        // require(balanceToBefore + _tokens == balanceToAfter);

        // uint _allowance = IERC20(token).allowance(from, address(this));
        // console.log("_allowance", _allowance);
        //
        // if (_allowance < _tokens) {
        //     revert TransferFromFailedApproval(token, from, to, _tokens, _allowance);
        // }

        // Handle ERC20 tokens that do not return true/false
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, _tokens));
        // require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');

        if (success && (data.length == 0 || abi.decode(data, (bool)))) {
        } else {
            revert TransferFromFailed(token, from, to, _tokens);
        }

        // try token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, _tokens)) returns (bool success, bytes memory data) {
        //     return;
        // } catch (bytes memory) {
        //     revert TransferFromFailed(token, from, to, _tokens);
        // }
    }


    // TODO
    // function recoverTokens(address token, uint tokens) public onlyOwner {
    //     if (token == address(0)) {
    //         payable(uint160(owner)).transfer((tokens == 0 ? address(this).balance : tokens));
    //     } else {
    //         IERC20(token).transfer(owner, tokens == 0 ? IERC20(token).balanceOf(address(this)) : tokens);
    //     }
    // }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Orders Data Structure
// ----------------------------------------------------------------------------
contract Orders is DexzBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    // Note that the BUY and SELL flags are used as indices
    uint8 constant public ORDERTYPE_BUY = 0x00;
    uint8 constant public ORDERTYPE_SELL = 0x01;
    uint constant public ORDERFLAG_BUYSELL_MASK = 0x01;
    // BK Default is to fill as much as possible
    uint constant public ORDERFLAG_FILL = 0x00;
    uint constant public ORDERFLAG_FILLALL_OR_REVERT = 0x10;
    uint constant public ORDERFLAG_FILL_AND_ADD_ORDER = 0x20;

    struct Order {
        OrderKey next;
        address maker;
        BuySell buySell;
        Price price;            // TODO: Delete as available in Price - ABC/WETH = 0.123 = #quoteToken per unit baseToken
        uint64 expiry;
        uint baseTokens;        // Original order
        uint baseTokensFilled;  // Filled order
    }
    struct OrderQueue {
        bool exists; // TODO Delete?
        OrderKey head;
        OrderKey tail;
    }

    // PairKey (bytes32) => BuySell => BPBRBTL(Price)
    mapping(PairKey => mapping(BuySell => BokkyPooBahsRedBlackTreeLibrary.Tree)) priceTrees;
    // PairKey (bytes32) => BuySell => Price => OrderQueue
    mapping(PairKey => mapping(BuySell => mapping(Price => OrderQueue))) orderQueue;
    // OrderKey (bytes32) => Order
    mapping(OrderKey => Order) orders;

    Price public constant PRICE_EMPTY = Price.wrap(0);
    OrderKey public constant ORDERKEY_SENTINEL = OrderKey.wrap(0x0);

    event OrderAdded(PairKey indexed pairKey, OrderKey indexed key, address indexed maker, BuySell buySell, Price price, uint64 expiry, uint baseTokens);
    event OrderRemoved(bytes32 indexed key);
    event OrderUpdated(bytes32 indexed key, uint baseTokens, uint newBaseTokens);


    constructor(address _feeAccount) DexzBase(_feeAccount) {
    }


    // Price tree navigating
    // BK TODO function count(bytes32 pairKey, uint _orderType) public view returns (uint _count) {
    // BK TODO     _count = priceTrees[pairKey][_orderType].count();
    // BK TODO }
    function first(PairKey pairKey, BuySell buySell) public view returns (Price key) {
        key = priceTrees[pairKey][buySell].first();
    }
    function last(PairKey pairKey, BuySell buySell) public view returns (Price key) {
        key = priceTrees[pairKey][buySell].last();
    }
    function next(PairKey pairKey, BuySell buySell, Price x) public view returns (Price y) {
        y = priceTrees[pairKey][buySell].next(x);
    }
    function prev(PairKey pairKey, BuySell buySell, Price x) public view returns (Price y) {
        y = priceTrees[pairKey][buySell].prev(x);
    }
    function exists(PairKey pairKey, BuySell buySell, Price key) public view returns (bool) {
        return priceTrees[pairKey][buySell].exists(key);
    }
    function getNode(PairKey pairKey, BuySell buySell, Price key) public view returns (Price returnKey, Price parent, Price left, Price right, uint8 red) {
        return priceTrees[pairKey][buySell].getNode(key);
    }
    // Don't need parent, grandparent, sibling, uncle


    // Orders navigating
    function generatePairKey(address _baseToken, address _quoteToken) internal pure returns (PairKey) {
        return PairKey.wrap(keccak256(abi.encodePacked(_baseToken, _quoteToken)));
    }
    function generateOrderKey(BuySell buySell, address _maker, address _baseToken, address _quoteToken, Price _price, uint64 _expiry) internal pure returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(buySell, _maker, _baseToken, _quoteToken, _price, _expiry)));
    }
    function exists(OrderKey key) internal view returns (bool) {
        return orders[key].expiry != 0;
    }
    function inverseBuySell(BuySell buySell) internal pure returns (BuySell inverse) {
        inverse = (buySell == BuySell.Buy) ? BuySell.Sell : BuySell.Buy;
    }


    function getBestPrice(PairKey pairKey, BuySell buySell) public view returns (Price key) {
        key = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].last() : priceTrees[pairKey][buySell].first();
    }
    function getNextBestPrice(PairKey pairKey, BuySell buySell, Price x) public view returns (Price y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(x)) {
            y = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].last() : priceTrees[pairKey][buySell].first();
        } else {
            y = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].prev(x) : priceTrees[pairKey][buySell].next(x);
        }
    }

    function isSentinel(OrderKey orderKey) internal pure returns (bool) {
        return OrderKey.unwrap(orderKey) == OrderKey.unwrap(ORDERKEY_SENTINEL);
    }
    function isNotSentinel(OrderKey orderKey) internal pure returns (bool) {
        return OrderKey.unwrap(orderKey) != OrderKey.unwrap(ORDERKEY_SENTINEL);
    }

    function getOrderQueue(PairKey pairKey, BuySell buySell, Price price) public view returns (bool _exists, OrderKey head, OrderKey tail) {
        Orders.OrderQueue memory _orderQueue = orderQueue[pairKey][buySell][price];
        return (_orderQueue.exists, _orderQueue.head, _orderQueue.tail);
    }
    // TODO check type _orderType
    function getOrder(OrderKey orderKey) public view returns (OrderKey _next, address maker, BuySell buySell, Price price, uint64 expiry, uint baseTokens, uint baseTokensFilled) {
        Orders.Order memory order = orders[orderKey];
        return (order.next, order.maker, order.buySell, order.price, order.expiry, order.baseTokens, order.baseTokensFilled);
    }


    function _getBestMatchingOrder(PairKey pairKey, BuySell buySell, Price price) internal returns (Price _bestMatchingPriceKey, OrderKey _bestMatchingOrderKey) {
        BuySell _matchingBuySell = inverseBuySell(buySell);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][_matchingBuySell];
        // SKINNY2 if (priceTree.initialised) {
            // emit LogInfo("getBestMatchingOrder: priceTree.initialised", 0, 0x0, "", address(0));
            _bestMatchingPriceKey = (buySell == BuySell.Buy) ? priceTree.first() : priceTree.last();
            bool priceOk = BokkyPooBahsRedBlackTreeLibrary.isEmpty(_bestMatchingPriceKey) ? false : (buySell == BuySell.Buy) ? Price.unwrap(_bestMatchingPriceKey) <= Price.unwrap(price) : Price.unwrap(_bestMatchingPriceKey) >= Price.unwrap(price);
            while (priceOk) {
                // emit LogInfo("getBestMatchingOrder: _bestMatchingPriceKey", uint(Price.unwrap(_bestMatchingPriceKey)), 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[pairKey][_matchingBuySell][_bestMatchingPriceKey];
                if (_orderQueue.exists) {
                    // emit LogInfo("getBestMatchingOrder: orderQueue not empty", uint(Price.unwrap(_bestMatchingPriceKey)), 0x0, "", address(0));
                    _bestMatchingOrderKey = _orderQueue.head;
                    while (isNotSentinel(_bestMatchingOrderKey)) {
                        Order storage order = orders[_bestMatchingOrderKey];
                        // emit LogInfo("getBestMatchingOrder: _bestMatchingOrderKey ", order.expiry, _bestMatchingOrderKey, "", address(0));
                        if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                            return (_bestMatchingPriceKey, _bestMatchingOrderKey);
                        }
                        _bestMatchingOrderKey = orders[_bestMatchingOrderKey].next;
                    }
                } else {
                    // TODO: REMOVE _bestMatchingPriceKey
                    emit LogInfo("getBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));
                }
                _bestMatchingPriceKey = (buySell == BuySell.Buy) ? priceTree.next(_bestMatchingPriceKey) : priceTree.prev(_bestMatchingPriceKey);
                priceOk = BokkyPooBahsRedBlackTreeLibrary.isEmpty(_bestMatchingPriceKey) ? false : (buySell == BuySell.Buy) ? Price.unwrap(_bestMatchingPriceKey) <= Price.unwrap(price) : Price.unwrap(_bestMatchingPriceKey) >= Price.unwrap(price);
            // SKINNY2 }
            // OrderQueue storage orderQueue = self.orderQueue[pairKey][_orderType][price];
        }
        return (BokkyPooBahsRedBlackTreeLibrary.getEmpty(), ORDERKEY_SENTINEL);
    }
    function _updateBestMatchingOrder(PairKey pairKey, BuySell buySell, Price matchingPriceKey, OrderKey matchingOrderKey, bool _orderFilled) internal returns (OrderKey orderKey) {
        BuySell _matchingBuySell = inverseBuySell(buySell);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][_matchingBuySell];
        // SKINNY2 if (priceTree.initialised) {
            // emit LogInfo("updateBestMatchingOrder: priceTree.initialised", 0, 0x0, "", address(0));
            Price priceKey = (buySell == BuySell.Buy) ? priceTree.first() : priceTree.last();
            while (!BokkyPooBahsRedBlackTreeLibrary.isEmpty(priceKey)) {
                // emit LogInfo("updateBestMatchingOrder: priceKey", uint(Price.unwrap(priceKey)), 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[pairKey][_matchingBuySell][priceKey];
                if (_orderQueue.exists) {
                    // emit LogInfo("updateBestMatchingOrder: orderQueue not empty", uint(Price.unwrap(priceKey)), 0x0, "", address(0));

                    Order storage order = orders[matchingOrderKey];
                    // TODO: What happens when allowance or balance is lower than #baseTokens
                    if (_orderFilled) {
                        _orderQueue.head = order.next;
                        // TODO
                        // if (order.next != ORDERKEY_SENTINEL) {
                        //     orders[order.next].prev = ORDERKEY_SENTINEL;
                        // }
                        // order.prev = ORDERKEY_SENTINEL;
                        if (OrderKey.unwrap(_orderQueue.tail) == OrderKey.unwrap(matchingOrderKey)) {
                            _orderQueue.tail = ORDERKEY_SENTINEL;
                        }
                        delete orders[matchingOrderKey];
                    // Else update head to current if not (skipped expired)
                    } else {
                        if (OrderKey.unwrap(_orderQueue.head) != OrderKey.unwrap(matchingOrderKey)) {
                            _orderQueue.head = matchingOrderKey;
                        }
                    }
                    // Clear out queue info, and prie tree if necessary
                    if (isSentinel(_orderQueue.head)) {
                        delete orderQueue[pairKey][_matchingBuySell][priceKey];
                        priceTree.remove(priceKey);
                        // emit LogInfo("orders remove RBT", uint(Price.unwrap(priceKey)), 0x0, "", address(0));
                    }
                } else {
                    priceTree.remove(priceKey);
                    emit LogInfo("updateBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                priceKey = (buySell == BuySell.Buy) ? priceTree.next(priceKey) : priceTree.prev(priceKey);
            // SKINNY2 }
        }
        return ORDERKEY_SENTINEL;
    }
    function _addOrder(BuySell buySell, address maker, address baseToken, address quoteToken, Price price, uint64 expiry, uint baseTokens) internal returns (OrderKey orderKey) {
        PairKey pairKey = generatePairKey(baseToken, quoteToken);
        orderKey = generateOrderKey(buySell, maker, baseToken, quoteToken, price, expiry);
        require(orders[orderKey].maker == address(0));
        addPair(pairKey, baseToken, quoteToken);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][buySell];
        if (!priceTree.exists(price)) {
            priceTree.insert(price);
        } else {
        }
        OrderQueue storage _orderQueue = orderQueue[pairKey][buySell][price];
        if (!_orderQueue.exists) {
            orderQueue[pairKey][buySell][price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            _orderQueue = orderQueue[pairKey][buySell][price];
        }
        if (isSentinel(_orderQueue.tail)) {
            _orderQueue.head = orderKey;
            _orderQueue.tail = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, maker, buySell, price, expiry, baseTokens, 0);
        } else {
            orders[_orderQueue.tail].next = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, maker, buySell, price, expiry, baseTokens, 0);
            _orderQueue.tail = orderKey;
        }
        emit OrderAdded(pairKey, orderKey, maker, buySell, price, expiry, baseTokens);
    }
    /*
    function _removeOrder(bytes32 orderKey, address msgSender) internal {
        require(orderKey != ORDERKEY_SENTINEL);
        Order memory order = orders[orderKey];
        require(order.maker == msgSender);

        bytes32 pairKey = generatePairKey(order.baseToken, order.quoteToken);
        OrderQueue storage _orderQueue = orderQueue[pairKey][order.buySell][order.price];
        require(_orderQueue.exists);

        BuySell buySell = order.buySell;
        Price _price = order.price;

        // Only order
        if (_orderQueue.head == orderKey && _orderQueue.tail == orderKey) {
            _orderQueue.head = ORDERKEY_SENTINEL;
            _orderQueue.tail = ORDERKEY_SENTINEL;
            delete orders[orderKey];
        // First item
        } else if (_orderQueue.head == orderKey) {
            bytes32 _next = orders[orderKey].next;
            // TODO
            // orders[_next].prev = ORDERKEY_SENTINEL;
            _orderQueue.head = _next;
            delete orders[orderKey];
        // Last item
        } else if (_orderQueue.tail == orderKey) {
            // TODO
            // bytes32 _prev = orders[orderKey].prev;
            // orders[_prev].next = ORDERKEY_SENTINEL;
            // _orderQueue.tail = _prev;
            // TODO
            _orderQueue.tail = ORDERKEY_SENTINEL;
            delete orders[orderKey];
        // Item in the middle
        } else {
            // TODO
            // bytes32 _prev = orders[orderKey].prev;
            bytes32 _next = orders[orderKey].next;
            // orders[_prev].next = ORDERKEY_SENTINEL;
            // orders[_next].prev = _prev;
            delete orders[orderKey];
        }
        emit OrderRemoved(orderKey);
        if (_orderQueue.head == ORDERKEY_SENTINEL && _orderQueue.tail == ORDERKEY_SENTINEL) {
            delete orderQueue[pairKey][buySell][_price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][buySell];
            if (priceTree.exists(_price)) {
                priceTree.remove(_price);
                // emit LogInfo("orders remove RBT", uint(Price.unwrap(_price)), 0x0, "", address(0));
            }
        }
    }
    */
}

enum BuySell { Buy, Sell }

enum Fill { Any, AllOrNothing, AnyAndAddOrder }

// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is Orders, ReentrancyGuard {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    struct TradeInfo {
        address taker;
        BuySell buySell;
        BuySell inverseBuySell;
        Fill fill;
        PairKey pairKey;
        address baseToken;
        address quoteToken;
        Price price;
        uint64 expiry;
        uint baseTokens;
        address uiFeeAccount;
    }

    // web3.sha3("trade(uint256,address,address,uint256,uint256,uint256,address)").substring(0, 10) => "0xcbb924e2"
    bytes4 public constant tradeSig = "\xcb\xb9\x24\xe2";

    event Trade(OrderKey indexed orderKey, BuySell buySell, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);

    constructor(address _feeAccount) Orders(_feeAccount) {
    }

    // // length = 4 + 7 * 32 = 228
    // uint private constant TRADE_DATA_LENGTH = 228;
    // function receiveApproval(address _from, uint256 _tokens, address _token, bytes memory _data) public {
    //     // emit LogInfo("receiveApproval: from", 0, 0x0, "", _from);
    //     // emit LogInfo("receiveApproval: tokens & token", _tokens, 0x0, "", _token);
    //     uint length;
    //     bytes4 functionSignature;
    //     uint orderFlag;
    //     uint baseToken;
    //     uint quoteToken;
    //     uint price;
    //     uint expiry;
    //     uint baseTokens;
    //     uint uiFeeAccount;
    //     assembly {
    //         length := mload(_data)
    //         functionSignature := mload(add(_data, 0x20))
    //         orderFlag := mload(add(_data, 0x24))
    //         baseToken := mload(add(_data, 0x44))
    //         quoteToken := mload(add(_data, 0x64))
    //         price := mload(add(_data, 0x84))
    //         expiry := mload(add(_data, 0xa4))
    //         baseTokens := mload(add(_data, 0xc4))
    //         uiFeeAccount := mload(add(_data, 0xe4))
    //     }
    //     // emit LogInfo("receiveApproval: length", length, 0x0, "", address(0));
    //     // emit LogInfo("receiveApproval: functionSignature", 0, bytes32(functionSignature), "", address(0));
    //     // emit LogInfo("receiveApproval: p1 orderFlag", orderFlag, 0x0, "", address(0));
    //     // emit LogInfo("receiveApproval: p2 baseToken", 0, 0x0, "", address(baseToken));
    //     // emit LogInfo("receiveApproval: p3 quoteToken", 0, 0x0, "", address(quoteToken));
    //     // emit LogInfo("receiveApproval: p4 price", price, 0x0, "", address(0));
    //     // emit LogInfo("receiveApproval: p5 expiry", expiry, 0x0, "", address(0));
    //     // emit LogInfo("receiveApproval: p6 baseTokens", baseTokens, 0x0, "", address(0));
    //     // emit LogInfo("receiveApproval: p7 uiFeeAccount", 0, 0x0, "", address(uiFeeAccount));
    //
    //     if (functionSignature == tradeSig) {
    //         require(length >= TRADE_DATA_LENGTH);
    //         require(_token == address(uint160(baseToken)) || _token == address(uint160(quoteToken)));
    //         require(_tokens >= baseTokens);
    //         _trade(TradeInfo(_from, orderFlag | ORDERFLAG_FILL_AND_ADD_ORDER, orderFlag & ORDERFLAG_BUYSELL_MASK, address(uint160(baseToken)), address(uint160(quoteToken)), price, expiry, baseTokens, address(uint160(uiFeeAccount))));
    //     }
    // }

    error InvalidPrice();

    function getMatchingBestPrice(TradeInfo memory tradeInfo) public view returns (Price price) {
        price = (tradeInfo.inverseBuySell == BuySell.Buy) ? priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].last() : priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].first();
    }
    function getMatchingNextBestPrice(TradeInfo memory tradeInfo, Price x) public view returns (Price y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(x)) {
            y = (tradeInfo.inverseBuySell == BuySell.Buy) ? priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].last() : priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].first();
        } else {
            y = (tradeInfo.inverseBuySell == BuySell.Buy) ? priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].prev(x) : priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell].next(x);
        }
    }
    function getMatchingOrderQueue(TradeInfo memory tradeInfo, Price price) public view returns (bool _exists, OrderKey head, OrderKey tail) {
        Orders.OrderQueue memory _orderQueue = orderQueue[tradeInfo.pairKey][tradeInfo.inverseBuySell][price];
        return (_orderQueue.exists, _orderQueue.head, _orderQueue.tail);
    }


    function tradeNew(BuySell buySell, Fill fill, address baseToken, address quoteToken, Price price, uint64 expiry, uint baseTokens, address uiFeeAccount) public payable reentrancyGuard returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 orderKey) {
        if (Price.unwrap(price) < Price.unwrap(PRICE_MIN) || Price.unwrap(price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice();
        }
        return _tradeNew(TradeInfo(msg.sender, buySell, inverseBuySell(buySell), fill, generatePairKey(baseToken, quoteToken), baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount));
    }

    // TODO: Delete the address fields?
    error InsufficientBaseTokenBalanceOrAllowance(address baseToken, uint baseTokens, uint allowance);
    error InsufficientQuoteTokenBalanceOrAllowance(address quoteToken, uint quoteTokens, uint allowance);

    event Trade1(PairKey indexed pairKey, OrderKey indexed orderKey, BuySell buySell, address indexed taker, address maker, uint baseTokens, uint quoteTokens, Price price);

    function _tradeNew(TradeInfo memory tradeInfo) internal returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 orderKey) {
        if (tradeInfo.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(tradeInfo.quoteToken, msg.sender);
            console.log("          * BUY - Taker quoteTokenAllowance %s: ", availableTokens);
            uint quoteTokens = tradeInfo.baseTokens * Price.unwrap(tradeInfo.price) / TENPOW9;
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(tradeInfo.quoteToken, quoteTokens, availableTokens);
            }
        } else {
            uint availableTokens = availableTokens(tradeInfo.baseToken, msg.sender);
            console.log("          * SELL - Taker baseTokenAllowance %s: ", availableTokens);
            if (availableTokens < tradeInfo.baseTokens) {
                revert InsufficientBaseTokenBalanceOrAllowance(tradeInfo.baseToken, tradeInfo.baseTokens, availableTokens);
            }
        }

        // uint tradeInfo.baseTokens = tradeInfo.baseTokens;
        Price bestMatchingPrice = getMatchingBestPrice(tradeInfo);
        // while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
        //        ((tradeInfo.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(tradeInfo.price)) ||
        //         (tradeInfo.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(tradeInfo.price))) &&
        //        tradeInfo.baseTokens > 0) {
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice)) {
            if (tradeInfo.buySell == BuySell.Buy) {
                if (Price.unwrap(bestMatchingPrice) > Price.unwrap(tradeInfo.price)) {
                    break;
                }
            } else if (tradeInfo.buySell == BuySell.Sell) {
                if (Price.unwrap(bestMatchingPrice) < Price.unwrap(tradeInfo.price)) {
                    break;
                }
            }
            if (tradeInfo.baseTokens == 0) {
                break;
            }
            console.log("          * bestMatchingPrice: %s, tradeInfo.baseTokens: %s", Price.unwrap(bestMatchingPrice), tradeInfo.baseTokens);
            Orders.OrderQueue storage _orderQueue = orderQueue[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
            // bytes32 prevBestMatchingOrderKey = ORDERKEY_SENTINEL;
            OrderKey bestMatchingOrderKey = _orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey) /*&& tradeInfo.baseTokens > 0*/) {
                Order storage order = orders[bestMatchingOrderKey];
                console.log("            * order - buySell: %s, baseTokens: %s, expiry: %s", uint(order.buySell), order.baseTokens, order.expiry);
                // console.logBytes32(prevBestMatchingOrderKey);
                // console.logBytes32(bestMatchingOrderKey);

                bool deleteOrder = false;
                if (order.expiry == 0 || order.expiry >= block.timestamp) {
                    uint makerBaseTokensToFill = order.baseTokens - order.baseTokensFilled;
                    uint baseTokensToTransfer;
                    uint quoteTokensToTransfer;
                    if (tradeInfo.buySell == BuySell.Buy) {
                        // Taker Buy Base / Maker Sell Quote
                        uint availableBaseTokens = availableTokens(tradeInfo.baseToken, order.maker);
                        if (availableBaseTokens > 0) {
                            console.log("              * Maker SELL base - availableBaseTokens: %s", availableBaseTokens);
                            if (makerBaseTokensToFill > availableBaseTokens) {
                                makerBaseTokensToFill = availableBaseTokens;
                            }
                            if (tradeInfo.baseTokens >= makerBaseTokensToFill) {
                                baseTokensToTransfer = makerBaseTokensToFill;
                                deleteOrder = true;
                            } else {
                                baseTokensToTransfer = tradeInfo.baseTokens;
                            }
                            quoteTokensToTransfer = baseTokensToTransfer * Price.unwrap(bestMatchingPrice) / TENPOW9;

                            // console.log("              * Base Transfer %s from %s to %s", baseTokensToTransfer, order.maker, msg.sender);
                            require(IERC20(tradeInfo.quoteToken).transferFrom(msg.sender, order.maker, quoteTokensToTransfer));
                            require(IERC20(tradeInfo.baseToken).transferFrom(order.maker, msg.sender, baseTokensToTransfer));

                            emit Trade1(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    } else {
                        // Taker Sell Base / Maker Buy Quote
                        uint availableQuoteTokens = availableTokens(tradeInfo.quoteToken, order.maker);
                        if (availableQuoteTokens > 0) {
                            console.log("              * Maker BUY quote - availableQuoteTokens: %s", availableQuoteTokens);
                            uint availableQuoteTokensInBaseTokens = availableQuoteTokens * TENPOW9 / Price.unwrap(bestMatchingPrice);
                            console.log("              * Maker BUY quote - availableQuoteTokensInBaseTokens: %s", availableQuoteTokensInBaseTokens);
                            if (makerBaseTokensToFill > availableQuoteTokensInBaseTokens) {
                                makerBaseTokensToFill = availableQuoteTokensInBaseTokens;
                            } else {
                                availableQuoteTokens = makerBaseTokensToFill * Price.unwrap(bestMatchingPrice) / TENPOW9;
                            }
                            if (tradeInfo.baseTokens >= makerBaseTokensToFill) {
                                baseTokensToTransfer = makerBaseTokensToFill;
                                quoteTokensToTransfer = availableQuoteTokens;
                                deleteOrder = true;
                            } else {
                                baseTokensToTransfer = tradeInfo.baseTokens;
                                quoteTokensToTransfer = baseTokensToTransfer * Price.unwrap(bestMatchingPrice) / TENPOW9;
                            }

                            console.log("              * Maker BUY quote - baseTokensToTransfer: %s", baseTokensToTransfer);

                            require(IERC20(tradeInfo.baseToken).transferFrom(msg.sender, order.maker, baseTokensToTransfer));
                            require(IERC20(tradeInfo.quoteToken).transferFrom(order.maker, msg.sender, quoteTokensToTransfer));
                            emit Trade1(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    }
                    order.baseTokensFilled += baseTokensToTransfer;
                    tradeInfo.baseTokens -= baseTokensToTransfer;
                    console.log("              * tradeInfo.baseTokens: %s, makerBaseTokens: %s, makerBaseTokensFilled: %s", tradeInfo.baseTokens, order.baseTokens, order.baseTokensFilled);
                    console.log("              * baseTokensToTransfer: %s, quoteTokensToTransfer: %s", baseTokensToTransfer, quoteTokensToTransfer);
                } else {
                    console.log("              * Expired");
                    deleteOrder = true;
                }
                console.log("              * Delete? %s", deleteOrder);

                // TODO
                if (deleteOrder) {
                    console.log("            - Deleting Order");
                    // console.logBytes32(prevBestMatchingOrderKey);
                    // console.logBytes32(bestMatchingOrderKey);
                    // // TODO delete and repoint head and tail
                    // if (_orderQueue.head == bestMatchingOrderKey) {
                    //     _orderQueue.head = order.next;
                    // } else {
                    //     // TODO
                    //     // orders[order.prev].next = order.next;
                    // }
                    // if (_orderQueue.tail == bestMatchingOrderKey) {
                    //     // TODO
                    //     // _orderQueue.tail = order.prev;
                    // } else {
                    //     // TODO
                    //     // orders[order.next].prev = order.prev;
                    // }
                    // prevBestMatchingOrderKey = bestMatchingOrderKey;
                    OrderKey temp = bestMatchingOrderKey;
                    bestMatchingOrderKey = order.next;
                    _orderQueue.head = order.next;
                    if (OrderKey.unwrap(_orderQueue.tail) == OrderKey.unwrap(bestMatchingOrderKey)) {
                        _orderQueue.tail = ORDERKEY_SENTINEL;
                    }
                    delete orders[temp];
                } else {
                    // console.log("          * Processing Order");
                    // TODO Check for valid order
                    //     // emit LogInfo("getBestMatchingOrder: _bestMatchingOrderKey ", order.expiry, _bestMatchingOrderKey, "", address(0));
                    //     if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                    //         return (_bestMatchingPriceKey, _bestMatchingOrderKey);
                    //     }
                    // prevBestMatchingOrderKey = bestMatchingOrderKey;
                    bestMatchingOrderKey = order.next;
                }
                if (tradeInfo.baseTokens == 0) {
                    break;
                }
            }
            // console.log("          * Checking Order Queue - head & tail");
            // console.logBytes32(_orderQueue.head);
            // console.logBytes32(_orderQueue.tail);
            if (isSentinel(_orderQueue.head) /*&& _orderQueue.tail == ORDERKEY_SENTINEL*/) {
                console.log("          * Deleting Order Queue");
                // TODO: Delete Queue
                delete orderQueue[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
                // TODO: Delete Price
                // console.log("          * Deleting Price");
                Price tempBestMatchingPrice = getMatchingNextBestPrice(tradeInfo, bestMatchingPrice);
                BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell];
                if (priceTree.exists(bestMatchingPrice)) {
                    priceTree.remove(bestMatchingPrice);
                    // console.log("          * Deleting Price from RBT");
                    // emit LogInfo("orders remove RBT", uint(Price.unwrap(_price)), 0x0, "", address(0));
                }
                bestMatchingPrice = tempBestMatchingPrice;
            } else {
                bestMatchingPrice = getMatchingNextBestPrice(tradeInfo, bestMatchingPrice);
            }
        }
    }

    function trade(BuySell buySell, Fill fill, address baseToken, address quoteToken, Price price, uint64 expiry, uint baseTokens, address uiFeeAccount) public payable returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, OrderKey orderKey) {
        if (Price.unwrap(price) < Price.unwrap(PRICE_MIN) || Price.unwrap(price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice();
        }
        return _trade(TradeInfo(msg.sender, buySell, inverseBuySell(buySell), fill, generatePairKey(baseToken, quoteToken), baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount));
    }
    function _trade(TradeInfo memory tradeInfo) internal returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, OrderKey orderKey) {
        Price matchingPriceKey;
        OrderKey matchingOrderKey;
        // bytes32 pairKey = pairKey(tradeInfo.baseToken, tradeInfo.quoteToken);
        (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(tradeInfo.pairKey, tradeInfo.buySell, tradeInfo.price);
        // emit LogInfo("_trade: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        uint loop = 0;
        while (isNotSentinel(matchingOrderKey) && tradeInfo.baseTokens > 0 && loop < 10) {
            uint _baseTokens;
            uint _quoteTokens;
            bool _orderFilled;
            Orders.Order storage order = orders[matchingOrderKey];
            // emit LogInfo("_trade: order", order.baseTokens, matchingOrderKey, "", order.maker);
            (_baseTokens, _quoteTokens, _orderFilled) = calculateOrder(matchingOrderKey, tradeInfo);
            // emit LogInfo("_trade: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            // emit LogInfo("_trade: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            if (_baseTokens > 0 && _quoteTokens > 0) {
                order.baseTokensFilled = order.baseTokensFilled + _baseTokens;
                transferTokens(tradeInfo, tradeInfo.buySell, order.maker, _baseTokens, _quoteTokens, matchingOrderKey);
                tradeInfo.baseTokens = tradeInfo.baseTokens - _baseTokens;
                _baseTokensFilled = _baseTokensFilled + _baseTokens;
                _quoteTokensFilled = _quoteTokensFilled + _quoteTokens;
                _updateBestMatchingOrder(tradeInfo.pairKey, tradeInfo.buySell, matchingPriceKey, matchingOrderKey, _orderFilled);
                // matchingOrderKey = ORDERKEY_SENTINEL;
                (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(tradeInfo.pairKey, tradeInfo.buySell, tradeInfo.price);
            }
            loop++;
            // break;
        }
        if (tradeInfo.fill == Fill.AllOrNothing) {
            require(tradeInfo.baseTokens == 0);
        }
        if (tradeInfo.baseTokens > 0 && (tradeInfo.fill == Fill.AnyAndAddOrder)) {
            // TODO Skip and remove expired items
            // TODO require(tradeInfo.expiry > block.timestamp);
            orderKey = _addOrder(tradeInfo.buySell, tradeInfo.taker, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price, tradeInfo.expiry, tradeInfo.baseTokens);
            _baseTokensOnOrder = tradeInfo.baseTokens;
        }
    }

    function calculateOrder(OrderKey _matchingOrderKey, TradeInfo memory tradeInfo) internal returns (uint baseTokens, uint quoteTokens, bool _orderFilled) {
        Orders.Order storage matchingOrder = orders[_matchingOrderKey];
        require(block.timestamp <= matchingOrder.expiry);

        // // Maker buying base, needs to have amount in quote = base x price
        // // Taker selling base, needs to have amount in base
        if (matchingOrder.buySell == BuySell.Buy) {
            // emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            // emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            // emit LogInfo("calculateOrder Maker Buy: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(tradeInfo.baseToken, tradeInfo.taker);
            // emit LogInfo("calculateOrder Maker Buy: availableTokens(baseToken, taker)", _availableBaseTokens, 0x0, "", taker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.baseTokens - matchingOrder.baseTokensFilled > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                // emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                // emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            // baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            // baseTokens = baseTokens.min(_availableBaseTokens);
            baseTokens = matchingOrder.baseTokens - matchingOrder.baseTokensFilled;
            if (tradeInfo.baseTokens < baseTokens) {
                baseTokens = tradeInfo.baseTokens;
            }
            if (_availableBaseTokens < baseTokens) {
                baseTokens = _availableBaseTokens;
            }
            // emit LogInfo("calculateOrder Maker Buy: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, taker))", baseTokens, 0x0, "", taker);

            // emit LogInfo("calculateOrder Maker Buy: quoteTokens = baseTokens x price / 1e18", baseTokens * matchingOrder.price / TENPOW18, 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(tradeInfo.quoteToken, matchingOrder.maker);
            // emit LogInfo("calculateOrder Maker Buy: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", matchingOrder.maker);
            if (matchingOrder.buySell == BuySell.Buy && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens * Price.unwrap(matchingOrder.price) / TENPOW9;
            if (_availableQuoteTokens < quoteTokens) {
                quoteTokens = _availableQuoteTokens;
            }
            // emit LogInfo("calculateOrder Maker Buy: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, matchingOrder.maker))", quoteTokens, 0x0, "", matchingOrder.maker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            if (quoteTokens * TENPOW9 / Price.unwrap(matchingOrder.price) < baseTokens) {
                baseTokens = quoteTokens * TENPOW9 / Price.unwrap(matchingOrder.price);
            }
            // baseTokens = baseTokens.min(quoteTokens * TENPOW9 / matchingOrder.price));
            // emit LogInfo("calculateOrder Maker Buy: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens * Price.unwrap(matchingOrder.price) / TENPOW9;
            // emit LogInfo("calculateOrder Maker Buy: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));

        // Maker selling base, needs to have amount in base
        // Taker buying base, needs to have amount in quote = base x price
        } else if (matchingOrder.buySell == BuySell.Sell) {
            // emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            // emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            // emit LogInfo("calculateOrder Maker Sell: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(tradeInfo.baseToken, matchingOrder.maker);
            // emit LogInfo("calculateOrder Maker Sell: availableTokens(matchingOrder.baseToken, matchingOrder.maker)", _availableBaseTokens, 0x0, "", matchingOrder.maker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.buySell == BuySell.Sell && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                // emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            // baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            // baseTokens = baseTokens.min(_availableBaseTokens);
            baseTokens = matchingOrder.baseTokens - matchingOrder.baseTokensFilled;
            if (tradeInfo.baseTokens < baseTokens) {
                baseTokens = tradeInfo.baseTokens;
            }
            if (_availableBaseTokens < baseTokens) {
                baseTokens = _availableBaseTokens;
            }
            // emit LogInfo("calculateOrder Maker Sell: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, matchingOrder.maker))", baseTokens, 0x0, "", matchingOrder.maker);

            // emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", baseTokens * Price.unwrap(matchingOrder.price) / TENPOW9, 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(tradeInfo.quoteToken, tradeInfo.taker);
            // emit LogInfo("calculateOrder Maker Sell: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", taker);
            if (matchingOrder.buySell == BuySell.Buy && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens * Price.unwrap(matchingOrder.price) / TENPOW9;
            if (_availableQuoteTokens < quoteTokens) {
                quoteTokens = _availableQuoteTokens;
            }
            // emit LogInfo("calculateOrder Maker Sell: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, taker))", quoteTokens, 0x0, "", taker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            // baseTokens = baseTokens.min(quoteTokens.mul(TENPOW9).div(matchingOrder.price));
            if (quoteTokens * TENPOW9 / Price.unwrap(matchingOrder.price) < baseTokens) {
                baseTokens = quoteTokens * TENPOW9 / Price.unwrap(matchingOrder.price);
            }

            // emit LogInfo("calculateOrder Maker Sell: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens * Price.unwrap(matchingOrder.price) / TENPOW9;
            // emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));
        }
        // TODO BK
        _orderFilled = true;
    }


    // function trade(uint orderType, address taker, address maker, address uiFeeAccount, address baseToken, address quoteToken, uint[2] memory tokens) internal {
    function transferTokens(TradeInfo memory tradeInfo, BuySell buySell, address maker, uint _baseTokens, uint _quoteTokens, OrderKey matchingOrderKey) internal {
        uint _takerFeeInTokens;
        // bool feeInEthers = (msg.value >= takerFeeInEthers);

        // TODO
        uint __orderBaseTokensFilled = 0;

        if (buySell == BuySell.Buy) {
            // emit LogInfo("transferTokens: BUY", 0, 0x0, "", address(0));
            _takerFeeInTokens = _baseTokens * takerFeeInTokens / TENPOW18;
            emit Trade(matchingOrderKey, buySell, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens - _takerFeeInTokens, _quoteTokens, _takerFeeInTokens, 0, __orderBaseTokensFilled);
            transferFrom(tradeInfo.quoteToken, tradeInfo.taker, maker, _quoteTokens);
            transferFrom(tradeInfo.baseToken, maker, tradeInfo.taker, _baseTokens - _takerFeeInTokens);
            if (_takerFeeInTokens > 0) {
                if (feeAccount == tradeInfo.uiFeeAccount || _takerFeeInTokens == 1) {
                    transferFrom(tradeInfo.baseToken, maker, feeAccount, _takerFeeInTokens);
                } else {
                    transferFrom(tradeInfo.baseToken, maker, tradeInfo.uiFeeAccount, _takerFeeInTokens / 2);
                    transferFrom(tradeInfo.baseToken, maker, feeAccount, _takerFeeInTokens - _takerFeeInTokens / 2);
                }
            }
        } else {
            // emit LogInfo("transferTokens: SELL", 0, 0x0, "", address(0));
            _takerFeeInTokens = _quoteTokens * takerFeeInTokens / TENPOW18;
            emit Trade(matchingOrderKey, buySell, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens, _quoteTokens - _takerFeeInTokens, _takerFeeInTokens, 0, __orderBaseTokensFilled);
            transferFrom(tradeInfo.baseToken, tradeInfo.taker, maker, _baseTokens);
            transferFrom(tradeInfo.quoteToken, maker, tradeInfo.taker, _quoteTokens - _takerFeeInTokens);
            if (_takerFeeInTokens > 0) {
                if (feeAccount == tradeInfo.uiFeeAccount || _takerFeeInTokens == 1) {
                    transferFrom(tradeInfo.quoteToken, maker, feeAccount, _takerFeeInTokens);
                } else {
                    transferFrom(tradeInfo.quoteToken, maker, tradeInfo.uiFeeAccount, _takerFeeInTokens / 2);
                    transferFrom(tradeInfo.quoteToken, maker, feeAccount, _takerFeeInTokens - _takerFeeInTokens / 2);
                }
            }
        }
    }


    /*
    function increaseOrderBaseTokens(bytes32 key, uint baseTokens) public returns (uint _newBaseTokens, uint _baseTokensFilled) {
        Order storage order = orders[key];
        require(order.maker == msg.sender);
        order.baseTokens = order.baseTokens.add(baseTokens);
        (_newBaseTokens, _baseTokensFilled) = (order.baseTokens, order.baseTokensFilled);
        emit OrderUpdated(key, baseTokens, _newBaseTokens);
    }
    function decreaseOrderBaseTokens(bytes32 key, uint baseTokens) public returns (uint _newBaseTokens, uint _baseTokensFilled) {
        Order storage order = orders[key];
        require(order.maker == msg.sender);
        if (order.baseTokensFilled.add(baseTokens) < order.baseTokens) {
            order.baseTokens = order.baseTokensFilled;
        } else {
            order.baseTokens = order.baseTokens.sub(baseTokens);
        }
        (_newBaseTokens, _baseTokensFilled) = (order.baseTokens, order.baseTokensFilled);
        emit OrderUpdated(key, baseTokens, _newBaseTokens);
    }
    function updateOrderPrice(OrderType orderType, address baseToken, address quoteToken, uint oldPrice, uint newPrice, uint expiry) public returns (uint _newBaseTokens) {
        bytes32 oldKey = Orders.generateOrderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, oldPrice, expiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.generateOrderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, newPrice, expiry);
        Order storage newOrder = orders[newKey];
        if (newOrder.maker != address(0)) {
            require(newOrder.maker == msg.sender);
            newOrder.baseTokens = newOrder.baseTokens.add(oldOrder.baseTokens.sub(oldOrder.baseTokensFilled));
            _newBaseTokens = newOrder.baseTokens;
        } else {
            orders[newKey] = Order(orderType, msg.sender, baseToken, quoteToken, newPrice, expiry, oldOrder.baseTokens.sub(oldOrder.baseTokensFilled), 0);
            userOrders[msg.sender].push(newKey);
            _newBaseTokens = oldOrder.baseTokens;
        }
        oldOrder.baseTokens = oldOrder.baseTokensFilled;
        // BK TODO: Log changes
    }
    function updateOrderExpiry(OrderType orderType, address baseToken, address quoteToken, uint price, uint oldExpiry, uint newExpiry) public returns (uint _newBaseTokens) {
        bytes32 oldKey = Orders.generateOrderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, oldExpiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.generateOrderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, newExpiry);
        Order storage newOrder = orders[newKey];
        if (newOrder.maker != address(0)) {
            require(newOrder.maker == msg.sender);
            newOrder.baseTokens = newOrder.baseTokens.add(oldOrder.baseTokens.sub(oldOrder.baseTokensFilled));
            _newBaseTokens = newOrder.baseTokens;
        } else {
            orders[newKey] = Order(orderType, msg.sender, baseToken, quoteToken, price, newExpiry, oldOrder.baseTokens.sub(oldOrder.baseTokensFilled), 0);
            userOrders[msg.sender].push(newKey);
            _newBaseTokens = oldOrder.baseTokens;
        }
        oldOrder.baseTokens = oldOrder.baseTokensFilled;
        // BK TODO: Log changes
    }
    function removeOrder(bytes32 key) public {
        _removeOrder(key, msg.sender);
    }
    */
}
