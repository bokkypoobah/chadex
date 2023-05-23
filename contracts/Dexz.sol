pragma solidity ^0.8.0;

// ----------------------------------------------------------------------------
// Dexz🤖, pronounced dex-zee, the token exchanger bot
//
// STATUS: In Development
//
// Notes:
//   quoteTokens = divisor * baseTokens * price / 10^9 / multiplier
//   baseTokens = multiplier * quoteTokens * 10^9 / price / divisor
//   price = multiplier * quoteTokens * 10^9 / baseTokens / divisor
// Including the 10^9 with the multiplier:
//   quoteTokens = divisor * baseTokens * price / multiplier
//   baseTokens = multiplier * quoteTokens / price / divisor
//   price = multiplier * quoteTokens / baseTokens / divisor
//
// TODO:
//   What happens when maker == taker?
//
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
// import "hardhat/console.sol";


type PairKey is bytes32;
type OrderKey is bytes32;
type Tokens is uint128;
type Unixtime is uint64;

enum BuySell { Buy, Sell }
// TODO: AddOrder, UpdateOrderExpiry, IncreaseOrderBaseTokens, DecreasesOrderBaseTokens
enum Action { FillAny, FillAllOrNothing, FillAnyAndAddOrder, AddOrder }


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


// ----------------------------------------------------------------------------
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    struct Pair {
        address baseToken;
        address quoteToken;
        uint multiplier;
        uint divisor;
    }
    struct OrderQueue {
        OrderKey head;
        OrderKey tail;
    }
    struct Order {
        OrderKey next;
        address maker;
        BuySell buySell;
        Unixtime expiry;
        Tokens baseTokens;
        Tokens baseTokensFilled;
    }
    struct TradeInfo {
        address taker;
        Action action;
        BuySell buySell;
        BuySell inverseBuySell;
        PairKey pairKey;
        Price price;
        Unixtime expiry;
        Tokens baseTokens;
    }

    uint constant public TENPOW18 = uint(10)**18;
    Price public constant PRICE_EMPTY = Price.wrap(0);
    Price public constant PRICE_MIN = Price.wrap(1);
    Price public constant PRICE_MAX = Price.wrap(999_999_999_999_999_999); // 2^64 = 18,446,744,073,709,551,616
    Tokens public constant TOKENS_MIN = Tokens.wrap(0);
    Tokens public constant TOKENS_MAX = Tokens.wrap(999_999_999_999_999_999_999_999_999_999_999); // 2^128 = 340,282,366,920,938,463,463,374,607,431,768,211,456
    OrderKey public constant ORDERKEY_SENTINEL = OrderKey.wrap(0x0);

    PairKey[] public pairKeys;
    mapping(PairKey => Pair) public pairs;
    mapping(PairKey => mapping(BuySell => BokkyPooBahsRedBlackTreeLibrary.Tree)) priceTrees;
    mapping(PairKey => mapping(BuySell => mapping(Price => OrderQueue))) orderQueues;
    mapping(OrderKey => Order) orders;

    event PairAdded(PairKey indexed pairKey, address indexed baseToken, address indexed quoteToken, uint8 baseDecimals, uint8 quoteDecimals, uint multiplier, uint divisor);
    event OrderAdded(PairKey indexed pairKey, OrderKey indexed key, address indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens baseTokens);
    event OrderRemoved(OrderKey indexed key);
    event OrderUpdated(OrderKey indexed key, uint baseTokens, uint newBaseTokens);
    event Trade(PairKey indexed pairKey, OrderKey indexed orderKey, BuySell buySell, address indexed taker, address maker, uint baseTokens, uint quoteTokens, Price price);
    event TradeSummary(BuySell buySell, address indexed taker, Tokens baseTokensFilled, Tokens quoteTokensFilled, Price price, Tokens baseTokensOnOrder);
    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);

    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Tokens tokenAmount, Tokens tokenAmountMax);
    error TransferFromFailedApproval(address token, address from, address to, uint _tokens, uint _approved);
    error TransferFromFailed(address token, address from, address to, uint _tokens);
    error InsufficientBaseTokenBalanceOrAllowance(address baseToken, Tokens baseTokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(address quoteToken, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens baseTokensUnfilled);

    constructor() {
    }

    function pair(uint i) public view returns (PairKey pairKey, address baseToken, address quoteToken, uint multiplier, uint divisor) {
        pairKey = pairKeys[i];
        Pair memory p = pairs[pairKey];
        return (pairKey, p.baseToken, p.quoteToken, p.multiplier, p.divisor);
    }
    function pairsLength() public view returns (uint) {
        return pairKeys.length;
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

    function getOrderQueue(PairKey pairKey, BuySell buySell, Price price) public view returns (OrderKey head, OrderKey tail) {
        OrderQueue memory orderQueue = orderQueues[pairKey][buySell][price];
        return (orderQueue.head, orderQueue.tail);
    }
    function getOrder(OrderKey orderKey) public view returns (OrderKey _next, address maker, BuySell buySell, Unixtime expiry, Tokens baseTokens, Tokens baseTokensFilled) {
        Order memory order = orders[orderKey];
        return (order.next, order.maker, order.buySell, order.expiry, order.baseTokens, order.baseTokensFilled);
    }

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

    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        uint _allowance = IERC20(token).allowance(wallet, address(this));
        uint _balance = IERC20(token).balanceOf(wallet);
        _tokens = _allowance < _balance ? _allowance : _balance;
    }
    function transferFrom(address token, address from, address to, uint _tokens) internal {
        // Handle ERC20 tokens that do not return true/false
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, _tokens));
        if (success && (data.length == 0 || abi.decode(data, (bool)))) {
        } else {
            revert TransferFromFailed(token, from, to, _tokens);
        }
    }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is DexzBase, ReentrancyGuard {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    constructor() DexzBase() {
    }

    function trade(Action action, BuySell buySell, address baseToken, address quoteToken, Price price, Unixtime expiry, Tokens baseTokens) public payable reentrancyGuard returns (Tokens baseTokensFilled, Tokens quoteTokensFilled, Tokens baseTokensOnOrder, OrderKey orderKey) {
        return _trade(_getTradeInfo(msg.sender, action, buySell, baseToken, quoteToken, price, expiry, baseTokens));
    }

    function _getTradeInfo(address taker, Action action, BuySell buySell, address baseToken, address quoteToken, Price price, Unixtime expiry, Tokens baseTokens) internal returns (TradeInfo memory tradeInfo) {
        if (Price.unwrap(price) < Price.unwrap(PRICE_MIN) || Price.unwrap(price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(price, PRICE_MAX);
        }
        if (Tokens.unwrap(baseTokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(baseTokens, TOKENS_MAX);
        }
        PairKey pairKey = generatePairKey(baseToken, quoteToken);
        if (pairs[pairKey].baseToken == address(0)) {
            uint8 baseDecimals = IERC20(baseToken).decimals();
            uint8 quoteDecimals = IERC20(quoteToken).decimals();
            uint multiplier;
            uint divisor;
            if (baseDecimals >= quoteDecimals) {
                multiplier = 10 ** uint(baseDecimals - quoteDecimals + 9);
                divisor = 1;
            } else {
                multiplier = 10 ** uint(9);
                divisor = 10 ** uint(quoteDecimals - baseDecimals);
            }
            pairs[pairKey] = Pair(baseToken, quoteToken, multiplier, divisor);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, baseToken, quoteToken, baseDecimals, quoteDecimals, multiplier, divisor);
        }
        return TradeInfo(taker, action, buySell, inverseBuySell(buySell), pairKey, price, expiry, baseTokens);
    }
    function _checkTakerAvailableTokens(Pair memory pair, TradeInfo memory tradeInfo) internal view {
        if (tradeInfo.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(pair.quoteToken, msg.sender);
            uint quoteTokens = pair.divisor * uint(Tokens.unwrap(tradeInfo.baseTokens)) * Price.unwrap(tradeInfo.price) / pair.multiplier;
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(pair.quoteToken, Tokens.wrap(uint128(quoteTokens)), Tokens.wrap(uint128(availableTokens)));
            }
        } else {
            uint availableTokens = availableTokens(pair.baseToken, msg.sender);
            if (availableTokens < uint(Tokens.unwrap(tradeInfo.baseTokens))) {
                revert InsufficientBaseTokenBalanceOrAllowance(pair.baseToken, tradeInfo.baseTokens, Tokens.wrap(uint128(availableTokens)));
            }
        }
    }
    function _addOrder(Pair memory pair, TradeInfo memory tradeInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(tradeInfo.buySell, tradeInfo.taker, pair.baseToken, pair.quoteToken, tradeInfo.price, tradeInfo.expiry);
        require(orders[orderKey].maker == address(0));
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[tradeInfo.pairKey][tradeInfo.buySell];
        if (!priceTree.exists(tradeInfo.price)) {
            priceTree.insert(tradeInfo.price);
        }
        OrderQueue storage orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.buySell][tradeInfo.price];
        if (isSentinel(orderQueue.head)) {
            orderQueues[tradeInfo.pairKey][tradeInfo.buySell][tradeInfo.price] = OrderQueue(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
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
    function _trade(TradeInfo memory tradeInfo) internal returns (Tokens baseTokensFilled, Tokens quoteTokensFilled, Tokens baseTokensOnOrder, OrderKey orderKey) {
        Pair memory pair = pairs[tradeInfo.pairKey];
        _checkTakerAvailableTokens(pair, tradeInfo);

        if (uint(tradeInfo.action) <= uint(Action.FillAnyAndAddOrder)) {
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
                OrderQueue storage orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
                OrderKey bestMatchingOrderKey = orderQueue.head;
                while (isNotSentinel(bestMatchingOrderKey) /*&& tradeInfo.baseTokens > 0*/) {
                    Order storage order = orders[bestMatchingOrderKey];
                    bool deleteOrder = false;
                    if (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) >= block.timestamp) {
                        uint makerBaseTokensToFill = Tokens.unwrap(order.baseTokens) - Tokens.unwrap(order.baseTokensFilled);
                        uint baseTokensToTransfer;
                        uint quoteTokensToTransfer;
                        if (tradeInfo.buySell == BuySell.Buy) {
                            // Taker Buy Base / Maker Sell Quote
                            uint availableBaseTokens = availableTokens(pair.baseToken, order.maker);
                            if (availableBaseTokens > 0) {
                                if (makerBaseTokensToFill > availableBaseTokens) {
                                    makerBaseTokensToFill = availableBaseTokens;
                                }
                                if (Tokens.unwrap(tradeInfo.baseTokens) >= makerBaseTokensToFill) {
                                    baseTokensToTransfer = makerBaseTokensToFill;
                                    deleteOrder = true;
                                } else {
                                    baseTokensToTransfer = uint(Tokens.unwrap(tradeInfo.baseTokens));
                                }
                                quoteTokensToTransfer = pair.divisor * baseTokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / pair.multiplier;
                                transferFrom(pair.quoteToken, msg.sender, order.maker, quoteTokensToTransfer);
                                transferFrom(pair.baseToken, order.maker, msg.sender, baseTokensToTransfer);
                                emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                            } else {
                                deleteOrder = true;
                            }
                        } else {
                            // Taker Sell Base / Maker Buy Quote
                            uint availableQuoteTokens = availableTokens(pair.quoteToken, order.maker);
                            if (availableQuoteTokens > 0) {
                                uint availableQuoteTokensInBaseTokens = pair.multiplier * availableQuoteTokens / uint(Price.unwrap(bestMatchingPrice)) / pair.divisor;
                                if (makerBaseTokensToFill > availableQuoteTokensInBaseTokens) {
                                    makerBaseTokensToFill = availableQuoteTokensInBaseTokens;
                                } else {
                                    availableQuoteTokens = pair.divisor * makerBaseTokensToFill * Price.unwrap(bestMatchingPrice) / pair.multiplier;
                                }
                                if (Tokens.unwrap(tradeInfo.baseTokens) >= makerBaseTokensToFill) {
                                    baseTokensToTransfer = makerBaseTokensToFill;
                                    quoteTokensToTransfer = availableQuoteTokens;
                                    deleteOrder = true;
                                } else {
                                    baseTokensToTransfer = uint(Tokens.unwrap(tradeInfo.baseTokens));
                                    quoteTokensToTransfer = pair.divisor * baseTokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / pair.multiplier;
                                }
                                transferFrom(pair.baseToken, msg.sender, order.maker, baseTokensToTransfer);
                                transferFrom(pair.quoteToken, order.maker, msg.sender, quoteTokensToTransfer);
                                emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, msg.sender, order.maker, baseTokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                            } else {
                                deleteOrder = true;
                            }
                        }
                        order.baseTokensFilled = Tokens.wrap(Tokens.unwrap(order.baseTokensFilled) + uint128(baseTokensToTransfer));
                        baseTokensFilled = Tokens.wrap(Tokens.unwrap(baseTokensFilled) + uint128(baseTokensToTransfer));
                        quoteTokensFilled = Tokens.wrap(Tokens.unwrap(quoteTokensFilled) + uint128(quoteTokensToTransfer));
                        tradeInfo.baseTokens = Tokens.wrap(Tokens.unwrap(tradeInfo.baseTokens) - uint128(baseTokensToTransfer));
                    } else {
                        deleteOrder = true;
                    }
                    if (deleteOrder) {
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
            if (tradeInfo.action == Action.FillAllOrNothing) {
                if (Tokens.unwrap(tradeInfo.baseTokens) > 0) {
                    revert UnableToFillOrder(tradeInfo.baseTokens);
                }
            }
            if (Tokens.unwrap(tradeInfo.baseTokens) > 0 && (tradeInfo.action == Action.FillAnyAndAddOrder)) {
                // TODO Skip and remove expired items
                // TODO require(tradeInfo.expiry > block.timestamp);
                orderKey = _addOrder(pair, tradeInfo);
                baseTokensOnOrder = tradeInfo.baseTokens;
            }
            if (Tokens.unwrap(baseTokensFilled) > 0 || Tokens.unwrap(quoteTokensFilled) > 0) {
                uint256 price = Tokens.unwrap(baseTokensFilled) > 0 ? pair.multiplier * uint(Tokens.unwrap(quoteTokensFilled)) / uint(Tokens.unwrap(baseTokensFilled)) / pair.divisor : 0;
                emit TradeSummary(tradeInfo.buySell, msg.sender, baseTokensFilled, quoteTokensFilled, Price.wrap(uint64(price)), baseTokensOnOrder);
            }
        }
        // console.log("          * baseTokensFilled: %s, quoteTokensFilled: %s, baseTokensOnOrder: %s", baseTokensFilled, quoteTokensFilled, baseTokensOnOrder);
    }

    function getOrders(PairKey pairKey, BuySell buySell, uint size, Price price, OrderKey orderKey) public view returns (uint[] memory item) {
        item = new uint[](size);
        // for (uint i = 0; i < size; i++) {
        //     item[i] = i;
        // }
        uint i;
        price = getNextBestPrice(pairKey, buySell, price);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(price) && i < size) {
            item[i] = Price.unwrap(price);
            price = getNextBestPrice(pairKey, buySell, price);
            i++;
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
