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
// If you earn fees using your deployment of this code, or derivatives of this
// code, please send a proportionate amount to bokkypoobah.eth .
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


type PairKey is bytes32;
type OrderKey is bytes32;
type Tokens is uint128;
type Unixtime is uint64;
enum BuySell { Buy, Sell }
enum Fill { Any, AllOrNothing, AnyAndAddOrder }

// ----------------------------------------------------------------------------
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase {
    uint constant public TENPOW9 = uint(10)**9;
    uint constant public TENPOW18 = uint(10)**18;

    Price public constant PRICE_MIN = Price.wrap(1);
    Price public constant PRICE_MAX = Price.wrap(999_999_999_999_999_999); // 2^64 = 18,446,744,073,709,551,616

    Tokens public constant TOKENS_MIN = Tokens.wrap(0);
    Tokens public constant TOKENS_MAX = Tokens.wrap(999_999_999_999_999_999_999_999_999_999_999); // 2^128 = 340,282,366,920,938,463,463,374,607,431,768,211,456

    struct Pair {
        address baseToken;
        address quoteToken;
        uint8 baseDecimals;
        uint8 quoteDecimals;
        uint multiplier;
        uint divisor;
    }

    mapping(PairKey => Pair) public pairs;
    PairKey[] public pairKeys;

    event PairAdded(PairKey indexed pairKey, address indexed baseToken, address indexed quoteToken, uint8 baseDecimals, uint8 quoteDecimals, uint multiplier, uint divisor);
    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);

    constructor() {
    }

    function pair(uint i) public view returns (PairKey pairKey, address baseToken, address quoteToken, uint8 baseDecimals, uint8 quoteDecimals, uint multiplier, uint divisor) {
        pairKey = pairKeys[i];
        Pair memory _pair = pairs[pairKey];
        return (pairKey, _pair.baseToken, _pair.quoteToken, _pair.baseDecimals, _pair.quoteDecimals, _pair.multiplier, _pair.divisor);
    }
    function pairsLength() public view returns (uint) {
        return pairKeys.length;
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

    struct Order {
        OrderKey next;
        address maker;
        BuySell buySell;
        Unixtime expiry;
        Tokens baseTokens;
        Tokens baseTokensFilled;
    }
    struct OrderQueue {
        bool exists; // TODO Delete?
        OrderKey head;
        OrderKey tail;
    }

    mapping(PairKey => mapping(BuySell => BokkyPooBahsRedBlackTreeLibrary.Tree)) priceTrees;
    mapping(PairKey => mapping(BuySell => mapping(Price => OrderQueue))) orderQueues;
    mapping(OrderKey => Order) orders;

    Price public constant PRICE_EMPTY = Price.wrap(0);
    OrderKey public constant ORDERKEY_SENTINEL = OrderKey.wrap(0x0);

    event OrderAdded(PairKey indexed pairKey, OrderKey indexed key, address indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens baseTokens);
    event OrderRemoved(OrderKey indexed key);
    event OrderUpdated(OrderKey indexed key, uint baseTokens, uint newBaseTokens);

    constructor() DexzBase() {
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
    function generateOrderKey(BuySell buySell, address _maker, address _baseToken, address _quoteToken, Price _price, Unixtime _expiry) internal pure returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(buySell, _maker, _baseToken, _quoteToken, _price, _expiry)));
    }
    function exists(OrderKey key) internal view returns (bool) {
        return Unixtime.unwrap(orders[key].expiry) != 0;
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
        Orders.OrderQueue memory orderQueue = orderQueues[pairKey][buySell][price];
        return (orderQueue.exists, orderQueue.head, orderQueue.tail);
    }
    function getOrder(OrderKey orderKey) public view returns (OrderKey _next, address maker, BuySell buySell, Unixtime expiry, Tokens baseTokens, Tokens baseTokensFilled) {
        Orders.Order memory order = orders[orderKey];
        return (order.next, order.maker, order.buySell, order.expiry, order.baseTokens, order.baseTokensFilled);
    }

    /*
    function _removeOrder(bytes32 orderKey, address msgSender) internal {
        require(orderKey != ORDERKEY_SENTINEL);
        Order memory order = orders[orderKey];
        require(order.maker == msgSender);

        bytes32 pairKey = generatePairKey(order.baseToken, order.quoteToken);
        OrderQueue storage orderQueue = orderQueues[pairKey][order.buySell][order.price];
        require(orderQueue.exists);

        BuySell buySell = order.buySell;
        Price _price = order.price;

        // Only order
        if (orderQueue.head == orderKey && orderQueue.tail == orderKey) {
            orderQueue.head = ORDERKEY_SENTINEL;
            orderQueue.tail = ORDERKEY_SENTINEL;
            delete orders[orderKey];
        // First item
    } else if (orderQueue.head == orderKey) {
            bytes32 _next = orders[orderKey].next;
            // TODO
            // orders[_next].prev = ORDERKEY_SENTINEL;
            orderQueue.head = _next;
            delete orders[orderKey];
        // Last item
    } else if (orderQueue.tail == orderKey) {
            // TODO
            // bytes32 _prev = orders[orderKey].prev;
            // orders[_prev].next = ORDERKEY_SENTINEL;
            // orderQueue.tail = _prev;
            // TODO
            orderQueue.tail = ORDERKEY_SENTINEL;
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
        if (orderQueue.head == ORDERKEY_SENTINEL && orderQueue.tail == ORDERKEY_SENTINEL) {
            delete orderQueues[pairKey][buySell][_price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][buySell];
            if (priceTree.exists(_price)) {
                priceTree.remove(_price);
                // emit LogInfo("orders remove RBT", uint(Price.unwrap(_price)), 0x0, "", address(0));
            }
        }
    }
    */
}


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
        uint multiplier;
        uint divisor;
        Price price;
        Unixtime expiry;
        Tokens baseTokens;
    }

    // web3.sha3("trade(uint256,address,address,uint256,uint256,uint256,address)").substring(0, 10) => "0xcbb924e2"
    // bytes4 public constant tradeSig = "\xcb\xb9\x24\xe2";

    // event TradeOld(OrderKey indexed orderKey, BuySell buySell, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);
    event Trade(PairKey indexed pairKey, OrderKey indexed orderKey, BuySell buySell, address indexed taker, address maker, uint baseTokens, uint quoteTokens, Price price);
    event TradeSummary(BuySell buySell, address indexed taker, Tokens baseTokensFilled, Tokens quoteTokensFilled, Price price, Tokens baseTokensOnOrder);


    constructor() Orders() {
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

    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Tokens tokenAmount, Tokens tokenAmountMax);

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
        Orders.OrderQueue memory orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.inverseBuySell][price];
        return (orderQueue.exists, orderQueue.head, orderQueue.tail);
    }

    // function doSomething(address baseToken, address quoteToken) internal view {
    //     uint startGas = gasleft();
    //     (uint multiplier, uint divisor) = getMultiplierAndDivisor(baseToken, quoteToken);
    //     uint endGas = gasleft();
    //     console.log("multiplier: %s, divisor: %s", multiplier, divisor);
    //     console.log("gasleft - start: %s, end: %s, diff: %s", startGas, endGas, startGas - endGas);
    // }
    function trade(BuySell buySell, Fill fill, address baseToken, address quoteToken, Price price, Unixtime expiry, Tokens baseTokens) public payable reentrancyGuard returns (Tokens baseTokensFilled, Tokens quoteTokensFilled, Tokens baseTokensOnOrder, OrderKey orderKey) {
        return _trade(getTradeInfo(msg.sender, buySell, fill, baseToken, quoteToken, price, expiry, baseTokens));
    }

    // TODO: Delete the address fields?
    // TODO: What happens when maker == taker?
    error InsufficientBaseTokenBalanceOrAllowance(address baseToken, Tokens baseTokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(address quoteToken, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens baseTokensUnfilled);

    function getTradeInfo(address taker, BuySell buySell, Fill fill, address baseToken, address quoteToken, Price price, Unixtime expiry, Tokens baseTokens) internal returns (TradeInfo memory tradeInfo) {
        if (Price.unwrap(price) < Price.unwrap(PRICE_MIN) || Price.unwrap(price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(price, PRICE_MAX);
        }
        if (Tokens.unwrap(baseTokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(baseTokens, TOKENS_MAX);
        }
        PairKey pairKey = generatePairKey(baseToken, quoteToken);
        Pair memory pair = pairs[pairKey];
        if (pairs[pairKey].baseToken == address(0)) {
            uint8 baseDecimals = IERC20(baseToken).decimals();
            uint8 quoteDecimals = IERC20(quoteToken).decimals();
            uint multiplier;
            uint divisor;
            if (baseDecimals >= quoteDecimals) {
                multiplier = 10 ** uint(baseDecimals - quoteDecimals);
                divisor = 1;
            } else {
                multiplier = 1;
                divisor = 10 ** uint(quoteDecimals - baseDecimals);
            }
            pairs[pairKey] = Pair(baseToken, quoteToken, baseDecimals, quoteDecimals, multiplier, divisor);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, baseToken, quoteToken, baseDecimals, quoteDecimals, multiplier, divisor);
            pair = pairs[pairKey];
        }
        return TradeInfo(taker, buySell, inverseBuySell(buySell), fill, pairKey, baseToken, quoteToken, pair.multiplier, pair.divisor, price, expiry, baseTokens);
    }

    // quoteTokens = divisor * baseTokens * price / 10^9 / multiplier
    // baseTokens = multiplier * quoteTokens * 10^9 / price / divisor
    // price = multiplier * quoteTokens * 10^9 / baseTokens / divisor

    function checkTakerAvailableTokens(TradeInfo memory tradeInfo) internal view {
        if (tradeInfo.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(tradeInfo.quoteToken, msg.sender);
            uint quoteTokens = tradeInfo.divisor * uint(Tokens.unwrap(tradeInfo.baseTokens)) * Price.unwrap(tradeInfo.price) / TENPOW9 / tradeInfo.multiplier;
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(tradeInfo.quoteToken, Tokens.wrap(uint128(quoteTokens)), Tokens.wrap(uint128(availableTokens)));
            }
        } else {
            uint availableTokens = availableTokens(tradeInfo.baseToken, msg.sender);
            if (availableTokens < uint(Tokens.unwrap(tradeInfo.baseTokens))) {
                revert InsufficientBaseTokenBalanceOrAllowance(tradeInfo.baseToken, tradeInfo.baseTokens, Tokens.wrap(uint128(availableTokens)));
            }
        }
    }

    function _trade(TradeInfo memory tradeInfo) internal returns (Tokens baseTokensFilled, Tokens quoteTokensFilled, Tokens baseTokensOnOrder, OrderKey orderKey) {
        checkTakerAvailableTokens(tradeInfo);

        Price bestMatchingPrice = getMatchingBestPrice(tradeInfo);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
               ((tradeInfo.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(tradeInfo.price)) ||
                (tradeInfo.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(tradeInfo.price))) &&
               Tokens.unwrap(tradeInfo.baseTokens) > 0) {
        // while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice)) {
        //     if (tradeInfo.buySell == BuySell.Buy) {
        //         if (Price.unwrap(bestMatchingPrice) > Price.unwrap(tradeInfo.price)) {
        //             break;
        //         }
        //     } else if (tradeInfo.buySell == BuySell.Sell) {
        //         if (Price.unwrap(bestMatchingPrice) < Price.unwrap(tradeInfo.price)) {
        //             break;
        //         }
        //     }
        //     if (Tokens.unwrap(tradeInfo.baseTokens) == 0) {
        //         break;
        //     }
            // console.log("          * bestMatchingPrice: %s, tradeInfo.baseTokens: %s", Price.unwrap(bestMatchingPrice), tradeInfo.baseTokens);
            Orders.OrderQueue storage orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
            OrderKey bestMatchingOrderKey = orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey) /*&& tradeInfo.baseTokens > 0*/) {
                Order storage order = orders[bestMatchingOrderKey];
                // console.log("            * order - buySell: %s, baseTokens: %s, expiry: %s", uint(order.buySell), order.baseTokens, order.expiry);
                // console.logBytes32(prevBestMatchingOrderKey);
                // console.logBytes32(bestMatchingOrderKey);
                bool deleteOrder = false;
                if (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) >= block.timestamp) {
                    uint makerBaseTokensToFill = Tokens.unwrap(order.baseTokens) - Tokens.unwrap(order.baseTokensFilled);
                    uint baseTokensToTransfer;
                    uint quoteTokensToTransfer;
                    if (tradeInfo.buySell == BuySell.Buy) {
                        // Taker Buy Base / Maker Sell Quote
                        uint availableBaseTokens = availableTokens(tradeInfo.baseToken, order.maker);
                        if (availableBaseTokens > 0) {
                            // console.log("              * Maker SELL base - availableBaseTokens: %s", availableBaseTokens);
                            if (makerBaseTokensToFill > availableBaseTokens) {
                                makerBaseTokensToFill = availableBaseTokens;
                            }
                            if (Tokens.unwrap(tradeInfo.baseTokens) >= makerBaseTokensToFill) {
                                baseTokensToTransfer = makerBaseTokensToFill;
                                deleteOrder = true;
                            } else {
                                baseTokensToTransfer = uint(Tokens.unwrap(tradeInfo.baseTokens));
                            }
                            quoteTokensToTransfer = tradeInfo.divisor * baseTokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / TENPOW9 / tradeInfo.multiplier;
                            // console.log("              * Base Transfer %s from %s to %s", baseTokensToTransfer, order.maker, msg.sender);
                            require(IERC20(tradeInfo.quoteToken).transferFrom(msg.sender, order.maker, quoteTokensToTransfer));
                            require(IERC20(tradeInfo.baseToken).transferFrom(order.maker, msg.sender, baseTokensToTransfer));
                            emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    } else {
                        // Taker Sell Base / Maker Buy Quote
                        uint availableQuoteTokens = availableTokens(tradeInfo.quoteToken, order.maker);
                        if (availableQuoteTokens > 0) {
                            // console.log("              * Maker BUY quote - availableQuoteTokens: %s", availableQuoteTokens);
                            uint availableQuoteTokensInBaseTokens = tradeInfo.multiplier * availableQuoteTokens * TENPOW9 / uint(Price.unwrap(bestMatchingPrice)) / tradeInfo.divisor;
                            // console.log("              * Maker BUY quote - availableQuoteTokensInBaseTokens: %s", availableQuoteTokensInBaseTokens);
                            if (makerBaseTokensToFill > availableQuoteTokensInBaseTokens) {
                                makerBaseTokensToFill = availableQuoteTokensInBaseTokens;
                            } else {
                                availableQuoteTokens = tradeInfo.divisor * makerBaseTokensToFill * Price.unwrap(bestMatchingPrice) / TENPOW9 / tradeInfo.multiplier;
                            }
                            if (Tokens.unwrap(tradeInfo.baseTokens) >= makerBaseTokensToFill) {
                                baseTokensToTransfer = makerBaseTokensToFill;
                                quoteTokensToTransfer = availableQuoteTokens;
                                deleteOrder = true;
                            } else {
                                baseTokensToTransfer = uint(Tokens.unwrap(tradeInfo.baseTokens));
                                quoteTokensToTransfer = tradeInfo.divisor * baseTokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / TENPOW9 / tradeInfo.multiplier;
                            }
                            // console.log("              * Maker BUY quote - baseTokensToTransfer: %s", baseTokensToTransfer);
                            require(IERC20(tradeInfo.baseToken).transferFrom(msg.sender, order.maker, baseTokensToTransfer));
                            require(IERC20(tradeInfo.quoteToken).transferFrom(order.maker, msg.sender, quoteTokensToTransfer));
                            emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    }
                    order.baseTokensFilled = Tokens.wrap(Tokens.unwrap(order.baseTokensFilled) + uint128(baseTokensToTransfer));
                    baseTokensFilled = Tokens.wrap(Tokens.unwrap(baseTokensFilled) + uint128(baseTokensToTransfer));
                    quoteTokensFilled = Tokens.wrap(Tokens.unwrap(quoteTokensFilled) + uint128(quoteTokensToTransfer));
                    tradeInfo.baseTokens = Tokens.wrap(Tokens.unwrap(tradeInfo.baseTokens) - uint128(baseTokensToTransfer));
                    // console.log("              * tradeInfo.baseTokens: %s, makerBaseTokens: %s, makerBaseTokensFilled: %s", tradeInfo.baseTokens, order.baseTokens, order.baseTokensFilled);
                    // console.log("              * baseTokensToTransfer: %s, quoteTokensToTransfer: %s", baseTokensToTransfer, quoteTokensToTransfer);
                } else {
                    // console.log("              * Expired");
                    deleteOrder = true;
                }
                // console.log("              * Delete? %s", deleteOrder);
                if (deleteOrder) {
                    // console.log("            - Deleting Order");
                    OrderKey temp = bestMatchingOrderKey;
                    bestMatchingOrderKey = order.next;
                    orderQueue.head = order.next;
                    if (OrderKey.unwrap(orderQueue.tail) == OrderKey.unwrap(bestMatchingOrderKey)) {
                        orderQueue.tail = ORDERKEY_SENTINEL;
                    }
                    delete orders[temp];
                } else {
                    bestMatchingOrderKey = order.next;
                }
                if (Tokens.unwrap(tradeInfo.baseTokens) == 0) {
                    break;
                }
            }
            // console.log("          * Checking Order Queue - head & tail");
            // console.logBytes32(orderQueue.head);
            // console.logBytes32(orderQueue.tail);
            if (isSentinel(orderQueue.head) /*&& orderQueue.tail == ORDERKEY_SENTINEL*/) {
                // console.log("          * Deleting Order Queue");
                delete orderQueues[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
                Price tempBestMatchingPrice = getMatchingNextBestPrice(tradeInfo, bestMatchingPrice);
                BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[tradeInfo.pairKey][tradeInfo.inverseBuySell];
                if (priceTree.exists(bestMatchingPrice)) {
                    priceTree.remove(bestMatchingPrice);
                }
                bestMatchingPrice = tempBestMatchingPrice;
            } else {
                bestMatchingPrice = getMatchingNextBestPrice(tradeInfo, bestMatchingPrice);
            }
        }
        if (tradeInfo.fill == Fill.AllOrNothing) {
            if (Tokens.unwrap(tradeInfo.baseTokens) > 0) {
                revert UnableToFillOrder(tradeInfo.baseTokens);
            }
        }
        if (Tokens.unwrap(tradeInfo.baseTokens) > 0 && (tradeInfo.fill == Fill.AnyAndAddOrder)) {
            // TODO Skip and remove expired items
            // TODO require(tradeInfo.expiry > block.timestamp);
            orderKey = _addOrder(tradeInfo);
            baseTokensOnOrder = tradeInfo.baseTokens;
        }
        if (Tokens.unwrap(baseTokensFilled) > 0 || Tokens.unwrap(quoteTokensFilled) > 0) {
            uint256 price = Tokens.unwrap(baseTokensFilled) > 0 ? tradeInfo.multiplier * uint(Tokens.unwrap(quoteTokensFilled)) * TENPOW9 / uint(Tokens.unwrap(baseTokensFilled)) / tradeInfo.divisor : 0;
            emit TradeSummary(tradeInfo.buySell, msg.sender, baseTokensFilled, quoteTokensFilled, Price.wrap(uint64(price)), baseTokensOnOrder);
        }
        // console.log("          * baseTokensFilled: %s, quoteTokensFilled: %s, baseTokensOnOrder: %s", baseTokensFilled, quoteTokensFilled, baseTokensOnOrder);
    }

    function _addOrder(TradeInfo memory tradeInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(tradeInfo.buySell, tradeInfo.taker, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price, tradeInfo.expiry);
        require(orders[orderKey].maker == address(0));
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[tradeInfo.pairKey][tradeInfo.buySell];
        if (!priceTree.exists(tradeInfo.price)) {
            priceTree.insert(tradeInfo.price);
        } else {
        }
        OrderQueue storage orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.buySell][tradeInfo.price];
        if (!orderQueue.exists) {
            orderQueues[tradeInfo.pairKey][tradeInfo.buySell][tradeInfo.price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.buySell][tradeInfo.price];
        }
        if (isSentinel(orderQueue.tail)) {
            orderQueue.head = orderKey;
            orderQueue.tail = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, tradeInfo.taker, tradeInfo.buySell, tradeInfo.expiry, tradeInfo.baseTokens, Tokens.wrap(0));
        } else {
            orders[orderQueue.tail].next = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, tradeInfo.taker, tradeInfo.buySell, tradeInfo.expiry, tradeInfo.baseTokens, Tokens.wrap(0));
            orderQueue.tail = orderKey;
        }
        emit OrderAdded(tradeInfo.pairKey, orderKey, tradeInfo.taker, tradeInfo.buySell, tradeInfo.price, tradeInfo.expiry, tradeInfo.baseTokens);
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
