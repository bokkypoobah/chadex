pragma solidity ^0.8.0;

import "./BokkyPooBahsRedBlackTreeLibrary.sol";
// import "hardhat/console.sol";

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
//   * bulkTrade
//   * updateExpiryAndTokens
//   * What happens when maker == taker?
//   * Check limits for Tokens(uint128) x Price(uint64)
//   * Serverless UI
//   * ?computeTrade
//   * ?updatePriceExpiryAndTokens
//   * ?oracle
//   * ?Optional backend services
//
// https://github.com/bokkypoobah/Dexz
//
// SPDX-License-Identifier: MIT
//
// If you earn fees using your deployment of this code, or derivatives of this
// code, please send a proportionate amount to bokkypoobah.eth .
// Don't be stingy!
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

type Account is address;
type Delta is int128;
type Factor is uint8;
type OrderKey is bytes32;
type PairKey is bytes32;
type Token is address;
type Tokens is uint128;
type Unixtime is uint64;

enum BuySell { Buy, Sell }
// TODO: RemoveOrders, UpdateOrderExpiry, IncreaseOrderBaseTokens, DecreasesOrderBaseTokens
enum Action { FillAny, FillAllOrNothing, FillAnyAndAddOrder }


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


function onePlus(uint x) pure returns (uint) {
    unchecked { return 1 + x; }
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
        Token base;
        Token quote;
        Factor multiplier;
        Factor divisor;
    }
    struct OrderQueue {
        OrderKey head;
        OrderKey tail;
    }
    struct Order {
        OrderKey next;
        Account maker;
        Unixtime expiry;
        Tokens tokens;
        Tokens filled;
    }
    struct TradeInfo {
        Account taker;
        Action action;
        BuySell buySell;
        BuySell inverseBuySell;
        PairKey pairKey;
        Price price;
        Unixtime expiry;
        Tokens tokens;
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

    event PairAdded(PairKey indexed pairKey, Token indexed base, Token indexed quote, uint8 baseDecimals, uint8 quoteDecimals, Factor multiplier, Factor divisor);
    event OrderAdded(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens tokens);
    event OrderRemoved(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Tokens tokens, Tokens filled);
    event OrderUpdated(OrderKey indexed key, uint tokens, uint newTokens);
    event Trade(PairKey indexed pairKey, OrderKey indexed orderKey, BuySell buySell, Account indexed taker, Account maker, uint tokens, uint quoteTokens, Price price);
    event TradeSummary(BuySell buySell, Account indexed taker, Tokens filled, Tokens quoteTokensFilled, Price price, Tokens tokensOnOrder);

    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Tokens tokenAmount, Tokens tokenAmountMax);
    error TransferFromFailedApproval(Token token, Account from, Account to, uint _tokens, uint _approved);
    error TransferFromFailed(Token token, Account from, Account to, uint _tokens);
    error InsufficientTokenBalanceOrAllowance(Token base, Tokens tokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(Token quote, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens unfilled);
    error CannotRemoveSomeoneElsesOrder(Account maker);

    constructor() {
    }

    function pair(uint i) public view returns (PairKey pairKey, Token base, Token quote, Factor multiplier, Factor divisor) {
        pairKey = pairKeys[i];
        Pair memory p = pairs[pairKey];
        return (pairKey, p.base, p.quote, p.multiplier, p.divisor);
    }
    function pairsLength() public view returns (uint) {
        return pairKeys.length;
    }

    // Price tree navigating
    // BK TODO function count(bytes32 pairKey, uint _orderType) public view returns (uint _count) {
    // BK TODO     _count = priceTrees[pairKey][_orderType].count();
    // BK TODO }
    function first(PairKey pairKey, BuySell buySell) public view returns (Price price) {
        price = priceTrees[pairKey][buySell].first();
    }
    function last(PairKey pairKey, BuySell buySell) public view returns (Price price) {
        price = priceTrees[pairKey][buySell].last();
    }
    function next(PairKey pairKey, BuySell buySell, Price price) public view returns (Price nextPrice) {
        nextPrice = priceTrees[pairKey][buySell].next(price);
    }
    function prev(PairKey pairKey, BuySell buySell, Price price) public view returns (Price prevPrice) {
        prevPrice = priceTrees[pairKey][buySell].prev(price);
    }
    function exists(PairKey pairKey, BuySell buySell, Price price) public view returns (bool) {
        return priceTrees[pairKey][buySell].exists(price);
    }
    function getNode(PairKey pairKey, BuySell buySell, Price price) public view returns (Price returnKey, Price parent, Price left, Price right, uint8 red) {
        return priceTrees[pairKey][buySell].getNode(price);
    }
    // Don't need parent, grandparent, sibling, uncle

    // Orders navigating
    function generatePairKey(Token base, Token quote) internal pure returns (PairKey) {
        return PairKey.wrap(keccak256(abi.encodePacked(base, quote)));
    }
    function generateOrderKey(BuySell buySell, Account maker, Token base, Token quote, Price price, Unixtime expiry) internal pure returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(buySell, maker, base, quote, price, expiry)));
    }
    function exists(OrderKey key) internal view returns (bool) {
        return Account.unwrap(orders[key].maker) != address(0);
    }
    function inverseBuySell(BuySell buySell) internal pure returns (BuySell inverse) {
        inverse = (buySell == BuySell.Buy) ? BuySell.Sell : BuySell.Buy;
    }

    function getBestPrice(PairKey pairKey, BuySell buySell) public view returns (Price price) {
        price = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].last() : priceTrees[pairKey][buySell].first();
    }
    function getNextBestPrice(PairKey pairKey, BuySell buySell, Price price) public view returns (Price nextBestPrice) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(price)) {
            nextBestPrice = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].last() : priceTrees[pairKey][buySell].first();
        } else {
            nextBestPrice = (buySell == BuySell.Buy) ? priceTrees[pairKey][buySell].prev(price) : priceTrees[pairKey][buySell].next(price);
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
    function getOrder(OrderKey orderKey) public view returns (OrderKey _next, Account maker, Unixtime expiry, Tokens tokens, Tokens filled) {
        Order memory order = orders[orderKey];
        return (order.next, order.maker, order.expiry, order.tokens, order.filled);
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

    function availableTokens(Token token, Account wallet) internal view returns (uint tokens) {
        uint allowance = IERC20(Token.unwrap(token)).allowance(Account.unwrap(wallet), address(this));
        uint balance = IERC20(Token.unwrap(token)).balanceOf(Account.unwrap(wallet));
        tokens = allowance < balance ? allowance : balance;
    }
    function transferFrom(Token token, Account from, Account to, uint tokens) internal {
        (bool success, bytes memory data) = Token.unwrap(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, Account.unwrap(from), Account.unwrap(to), tokens));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFromFailed(token, from, to, tokens);
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

    function trade(Action action, BuySell buySell, Token base, Token quote, Price price, Unixtime expiry, Tokens tokens, OrderKey[] calldata orderKeys) public reentrancyGuard returns (Tokens filled, Tokens quoteTokensFilled, Tokens tokensOnOrder, OrderKey orderKey) {
        if (uint(action) <= uint(Action.FillAnyAndAddOrder)) {
            return _trade(_getTradeInfo(Account.wrap(msg.sender), action, buySell, base, quote, price, expiry, tokens));
        }
    }

    struct Info {
        Action action;
        BuySell buySell;
        Token base;
        Token quote;
        Price price;
        Unixtime expiry;
        Delta tokens;
        OrderKey[] orderKeys;
    }

    event LogInfo(Info info);
    function bulkTrade(Info[] calldata infos) public {
        for (uint i = 0; i < infos.length; i = onePlus(i)) {
            Info memory info = infos[i];
            emit LogInfo(info);
        }
    }

    function removeOrders(PairKey[] calldata _pairKeys, BuySell[] calldata buySells, OrderKey[][] calldata orderKeyss) public {
        for (uint i; i < _pairKeys.length; i = onePlus(i)) {
            PairKey pairKey = _pairKeys[i];
            BuySell buySell = buySells[i];
            OrderKey[] memory orderKeys = orderKeyss[i];
            Price price = getBestPrice(pairKey, buySell);
            while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(price)) {
                OrderQueue storage orderQueue = orderQueues[pairKey][buySell][price];
                OrderKey orderKey = orderQueue.head;
                OrderKey prevOrderKey;
                while (isNotSentinel(orderKey)) {
                    bool deleteOrder = false;
                    for (uint j = 0; j< orderKeys.length && !deleteOrder; j = onePlus(j)) {
                        if (OrderKey.unwrap(orderKeys[j]) == OrderKey.unwrap(orderKey)) {
                            deleteOrder = true;
                        }
                    }
                    Order memory order = orders[orderKey];
                    if (deleteOrder) {
                        if (Account.unwrap(order.maker) != msg.sender) {
                            revert CannotRemoveSomeoneElsesOrder(order.maker);
                        }
                        OrderKey temp = orderKey;
                        emit OrderRemoved(pairKey, orderKey, order.maker, buySell, price, order.tokens, order.filled);
                        if (OrderKey.unwrap(orderQueue.head) == OrderKey.unwrap(orderKey)) {
                            orderQueue.head = order.next;
                        } else {
                            orders[prevOrderKey].next = order.next;
                        }
                        if (OrderKey.unwrap(orderQueue.tail) == OrderKey.unwrap(orderKey)) {
                            orderQueue.tail = prevOrderKey;
                        }
                        prevOrderKey = orderKey;
                        orderKey = order.next;
                        delete orders[temp];
                    } else {
                        prevOrderKey = orderKey;
                        orderKey = order.next;
                    }
                }
                if (isSentinel(orderQueue.head)) {
                    delete orderQueues[pairKey][buySell][price];
                    Price tempPrice = getNextBestPrice(pairKey, buySell, price);
                    BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[pairKey][buySell];
                    if (priceTree.exists(price)) {
                        priceTree.remove(price);
                    }
                    price = tempPrice;
                } else {
                    price = getNextBestPrice(pairKey, buySell, price);
                }
            }
        }
    }

    function _getTradeInfo(Account taker, Action action, BuySell buySell, Token base, Token quote, Price price, Unixtime expiry, Tokens tokens) internal returns (TradeInfo memory tradeInfo) {
        if (Price.unwrap(price) < Price.unwrap(PRICE_MIN) || Price.unwrap(price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(price, PRICE_MAX);
        }
        if (Tokens.unwrap(tokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(tokens, TOKENS_MAX);
        }
        PairKey pairKey = generatePairKey(base, quote);
        if (Token.unwrap(pairs[pairKey].base) == address(0)) {
            uint8 baseDecimals = IERC20(Token.unwrap(base)).decimals();
            uint8 quoteDecimals = IERC20(Token.unwrap(quote)).decimals();
            Factor multiplier;
            Factor divisor;
            if (baseDecimals >= quoteDecimals) {
                multiplier = Factor.wrap(baseDecimals - quoteDecimals + 9);
                divisor = Factor.wrap(0);
            } else {
                multiplier = Factor.wrap(9);
                divisor = Factor.wrap(quoteDecimals - baseDecimals);
            }
            pairs[pairKey] = Pair(base, quote, multiplier, divisor);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, base, quote, baseDecimals, quoteDecimals, multiplier, divisor);
        }
        return TradeInfo(taker, action, buySell, inverseBuySell(buySell), pairKey, price, expiry, tokens);
    }
    function _checkTakerAvailableTokens(Pair memory pair, TradeInfo memory tradeInfo) internal view {
        if (tradeInfo.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(pair.quote, Account.wrap(msg.sender));
            uint quoteTokens = (10 ** Factor.unwrap(pair.divisor)) * uint(Tokens.unwrap(tradeInfo.tokens)) * Price.unwrap(tradeInfo.price) / (10 ** Factor.unwrap(pair.multiplier));
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(pair.quote, Tokens.wrap(uint128(quoteTokens)), Tokens.wrap(uint128(availableTokens)));
            }
        } else {
            uint availableTokens = availableTokens(pair.base, Account.wrap(msg.sender));
            if (availableTokens < uint(Tokens.unwrap(tradeInfo.tokens))) {
                revert InsufficientTokenBalanceOrAllowance(pair.base, tradeInfo.tokens, Tokens.wrap(uint128(availableTokens)));
            }
        }
    }
    function _addOrder(Pair memory pair, TradeInfo memory tradeInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(tradeInfo.buySell, tradeInfo.taker, pair.base, pair.quote, tradeInfo.price, tradeInfo.expiry);
        require(Account.unwrap(orders[orderKey].maker) == address(0));
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
            orders[orderKey] = Order(ORDERKEY_SENTINEL, tradeInfo.taker, tradeInfo.expiry, tradeInfo.tokens, Tokens.wrap(0));
        } else {
            orders[orderQueue.tail].next = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, tradeInfo.taker, tradeInfo.expiry, tradeInfo.tokens, Tokens.wrap(0));
            orderQueue.tail = orderKey;
        }
        emit OrderAdded(tradeInfo.pairKey, orderKey, tradeInfo.taker, tradeInfo.buySell, tradeInfo.price, tradeInfo.expiry, tradeInfo.tokens);
    }
    function _trade(TradeInfo memory tradeInfo) internal returns (Tokens filled, Tokens quoteTokensFilled, Tokens tokensOnOrder, OrderKey orderKey) {
        Pair memory pair = pairs[tradeInfo.pairKey];
        _checkTakerAvailableTokens(pair, tradeInfo);

        Price bestMatchingPrice = getMatchingBestPrice(tradeInfo);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
               ((tradeInfo.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(tradeInfo.price)) ||
                (tradeInfo.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(tradeInfo.price))) &&
               Tokens.unwrap(tradeInfo.tokens) > 0) {
            OrderQueue storage orderQueue = orderQueues[tradeInfo.pairKey][tradeInfo.inverseBuySell][bestMatchingPrice];
            OrderKey bestMatchingOrderKey = orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey)) {
                Order storage order = orders[bestMatchingOrderKey];
                bool deleteOrder = false;
                if (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) >= block.timestamp) {
                    uint makerTokensToFill = Tokens.unwrap(order.tokens) - Tokens.unwrap(order.filled);
                    uint tokensToTransfer;
                    uint quoteTokensToTransfer;
                    if (tradeInfo.buySell == BuySell.Buy) {
                        uint availableBaseTokens = availableTokens(pair.base, order.maker);
                        if (availableBaseTokens > 0) {
                            if (makerTokensToFill > availableBaseTokens) {
                                makerTokensToFill = availableBaseTokens;
                            }
                            if (Tokens.unwrap(tradeInfo.tokens) >= makerTokensToFill) {
                                tokensToTransfer = makerTokensToFill;
                                deleteOrder = true;
                            } else {
                                tokensToTransfer = uint(Tokens.unwrap(tradeInfo.tokens));
                            }
                            quoteTokensToTransfer = (10 ** Factor.unwrap(pair.divisor)) * tokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / (10 ** Factor.unwrap(pair.multiplier));
                            transferFrom(pair.quote, Account.wrap(msg.sender), order.maker, quoteTokensToTransfer);
                            transferFrom(pair.base, order.maker, Account.wrap(msg.sender), tokensToTransfer);
                            emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, Account.wrap(msg.sender), order.maker, tokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    } else {
                        uint availableQuoteTokens = availableTokens(pair.quote, order.maker);
                        if (availableQuoteTokens > 0) {
                            uint availableQuoteTokensInBaseTokens = (10 ** Factor.unwrap(pair.multiplier)) * availableQuoteTokens / uint(Price.unwrap(bestMatchingPrice)) / (10 ** Factor.unwrap(pair.divisor));
                            if (makerTokensToFill > availableQuoteTokensInBaseTokens) {
                                makerTokensToFill = availableQuoteTokensInBaseTokens;
                            } else {
                                availableQuoteTokens = (10 ** Factor.unwrap(pair.divisor)) * makerTokensToFill * Price.unwrap(bestMatchingPrice) / (10 ** Factor.unwrap(pair.multiplier));
                            }
                            if (Tokens.unwrap(tradeInfo.tokens) >= makerTokensToFill) {
                                tokensToTransfer = makerTokensToFill;
                                quoteTokensToTransfer = availableQuoteTokens;
                                deleteOrder = true;
                            } else {
                                tokensToTransfer = uint(Tokens.unwrap(tradeInfo.tokens));
                                quoteTokensToTransfer = (10 ** Factor.unwrap(pair.divisor)) * tokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / (10 ** Factor.unwrap(pair.multiplier));
                            }
                            transferFrom(pair.base, Account.wrap(msg.sender), order.maker, tokensToTransfer);
                            transferFrom(pair.quote, order.maker, Account.wrap(msg.sender), quoteTokensToTransfer);
                            emit Trade(tradeInfo.pairKey, bestMatchingOrderKey, tradeInfo.buySell, Account.wrap(msg.sender), order.maker, tokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    }
                    order.filled = Tokens.wrap(Tokens.unwrap(order.filled) + uint128(tokensToTransfer));
                    filled = Tokens.wrap(Tokens.unwrap(filled) + uint128(tokensToTransfer));
                    quoteTokensFilled = Tokens.wrap(Tokens.unwrap(quoteTokensFilled) + uint128(quoteTokensToTransfer));
                    tradeInfo.tokens = Tokens.wrap(Tokens.unwrap(tradeInfo.tokens) - uint128(tokensToTransfer));
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
                if (Tokens.unwrap(tradeInfo.tokens) == 0) {
                    break;
                }
            }
            if (isSentinel(orderQueue.head)) {
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
            if (Tokens.unwrap(tradeInfo.tokens) > 0) {
                revert UnableToFillOrder(tradeInfo.tokens);
            }
        }
        if (Tokens.unwrap(tradeInfo.tokens) > 0 && (tradeInfo.action == Action.FillAnyAndAddOrder)) {
            // TODO require(tradeInfo.expiry > block.timestamp);
            orderKey = _addOrder(pair, tradeInfo);
            tokensOnOrder = tradeInfo.tokens;
        }
        if (Tokens.unwrap(filled) > 0 || Tokens.unwrap(quoteTokensFilled) > 0) {
            uint256 price = Tokens.unwrap(filled) > 0 ? (10 ** Factor.unwrap(pair.multiplier)) * uint(Tokens.unwrap(quoteTokensFilled)) / uint(Tokens.unwrap(filled)) / (10 ** Factor.unwrap(pair.divisor)) : 0;
            emit TradeSummary(tradeInfo.buySell, Account.wrap(msg.sender), filled, quoteTokensFilled, Price.wrap(uint64(price)), tokensOnOrder);
        }
    }

    function getOrders(PairKey pairKey, BuySell buySell, uint count, Price price, OrderKey firstOrderKey) public view returns (Price[] memory prices, OrderKey[] memory orderKeys, OrderKey[] memory nextOrderKeys, Account[] memory makers, Unixtime[] memory expiries, Tokens[] memory tokenss, Tokens[] memory filleds) {
        prices = new Price[](count);
        orderKeys = new OrderKey[](count);
        nextOrderKeys = new OrderKey[](count);
        makers = new Account[](count);
        expiries = new Unixtime[](count);
        tokenss = new Tokens[](count);
        filleds = new Tokens[](count);
        uint i;
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(price)) {
            price = getBestPrice(pairKey, buySell);
        } else {
            if (isSentinel(firstOrderKey)) {
                price = getNextBestPrice(pairKey, buySell, price);
            }
        }
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(price) && i < count) {
            OrderQueue memory orderQueue = orderQueues[pairKey][buySell][price];
            OrderKey orderKey = orderQueue.head;
            if (isNotSentinel(firstOrderKey)) {
                while (isNotSentinel(orderKey) && OrderKey.unwrap(orderKey) != OrderKey.unwrap(firstOrderKey)) {
                    Order memory order = orders[orderKey];
                    orderKey = order.next;
                }
                firstOrderKey = ORDERKEY_SENTINEL;
            }
            while (isNotSentinel(orderKey) && i < count) {
                Order memory order = orders[orderKey];
                prices[i] = price;
                orderKeys[i] = orderKey;
                nextOrderKeys[i] = order.next;
                makers[i] = order.maker;
                expiries[i] = order.expiry;
                tokenss[i] = order.tokens;
                filleds[i] = order.filled;
                orderKey = order.next;
                i = onePlus(i);
            }
            price = getNextBestPrice(pairKey, buySell, price);
        }
    }

    /*
    function increaseOrderBaseTokens(bytes32 key, uint tokens) public returns (uint _newBaseTokens, uint _filled) {
        Order storage order = orders[key];
        require(order.maker == msg.sender);
        order.baseTokens = order.baseTokens.add(baseTokens);
        (_newBaseTokens, _filled) = (order.baseTokens, order.filled);
        emit OrderUpdated(key, baseTokens, _newBaseTokens);
    }
    function decreaseOrderBaseTokens(bytes32 key, uint baseTokens) public returns (uint _newBaseTokens, uint _filled) {
        Order storage order = orders[key];
        require(order.maker == msg.sender);
        if (order.filled.add(baseTokens) < order.baseTokens) {
            order.baseTokens = order.filled;
        } else {
            order.baseTokens = order.baseTokens.sub(baseTokens);
        }
        (_newBaseTokens, _filled) = (order.baseTokens, order.filled);
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
            newOrder.baseTokens = newOrder.baseTokens.add(oldOrder.baseTokens.sub(oldOrder.filled));
            _newBaseTokens = newOrder.baseTokens;
        } else {
            orders[newKey] = Order(orderType, msg.sender, baseToken, quoteToken, newPrice, expiry, oldOrder.baseTokens.sub(oldOrder.filled), 0);
            userOrders[msg.sender].push(newKey);
            _newBaseTokens = oldOrder.baseTokens;
        }
        oldOrder.baseTokens = oldOrder.filled;
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
            newOrder.baseTokens = newOrder.baseTokens.add(oldOrder.baseTokens.sub(oldOrder.filled));
            _newBaseTokens = newOrder.baseTokens;
        } else {
            orders[newKey] = Order(orderType, msg.sender, baseToken, quoteToken, price, newExpiry, oldOrder.baseTokens.sub(oldOrder.filled), 0);
            userOrders[msg.sender].push(newKey);
            _newBaseTokens = oldOrder.baseTokens;
        }
        oldOrder.baseTokens = oldOrder.filled;
        // BK TODO: Log changes
    }
    function removeOrder(bytes32 key) public {
        _removeOrder(key, msg.sender);
    }
    */
}
