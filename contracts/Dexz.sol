pragma solidity ^0.8.0;

import "./BokkyPooBahsRedBlackTreeLibrary.sol";

// ----------------------------------------------------------------------------
// Dexz v 0.8.9a-testing
//
// Deployed to Sepolia
//
// TODO:
//   * Decide on checks for taker's balances
//   * Check limits for Tokens(uint128) x Price(uint64) and conversions
//   * Check cost of taking vs making expired or dummy orders
//   * Check remainder from divisions
//   * Serverless UI
//   * ?Move updated orders to the end of the queue
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
type Factor is uint8;
type OrderKey is bytes32;
type PairKey is bytes32;
type Token is address;
type Tokens is int128;
type Unixtime is uint64;

enum BuySell { Buy, Sell }
// TODO: Consider rolling UpdateExpiryAndTokens into FillAnyAndAddOrder
enum Action { FillAny, FillAllOrNothing, FillAnyAndAddOrder, RemoveOrder, UpdateExpiryAndTokens }


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


contract DexzBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    struct Factors {
        Factor multiplier;
        Factor divisor;
    }
    struct Pair {
        Token base;
        Token quote;
        Factors factors;
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
        // Tokens filled; // TODO: Remove
    }
    struct TradeInput {
        Action action;
        BuySell buySell;
        Token base;
        Token quote;
        Price price;
        Price targetPrice;
        Unixtime expiry;
        Tokens tokens;
    }
    struct MoreInfo {
        Account taker;
        BuySell inverseBuySell;
        PairKey pairKey;
        Factors factors;
    }
    struct TradeResult {
        PairKey pairKey;
        OrderKey orderKey;
        Account taker;
        Account maker;
        BuySell buySell;
        Price price;
        uint tokens;
        uint quoteTokens;
        uint timestamp;
    }

    uint8 public constant PRICE_DECIMALS = 12;
    Price public constant PRICE_EMPTY = Price.wrap(0);
    Price public constant PRICE_MIN = Price.wrap(1);
    Price public constant PRICE_MAX = Price.wrap(999_999_999_999_999_999_999_999); // 2^128 = 340, 282,366,920,938,463,463, 374,607,431,768,211,456
    Tokens public constant TOKENS_MIN = Tokens.wrap(0);
    Tokens public constant TOKENS_MAX = Tokens.wrap(999_999_999_999_999_999_999_999_999_999_999_999); // 2^128 = 340, 282,366,920, 938,463,463, 374,607,431, 768,211,456
    OrderKey public constant ORDERKEY_SENTINEL = OrderKey.wrap(0x0);

    PairKey[] public pairKeys;
    mapping(PairKey => Pair) public pairs;
    mapping(PairKey => mapping(BuySell => BokkyPooBahsRedBlackTreeLibrary.Tree)) priceTrees;
    mapping(PairKey => mapping(BuySell => mapping(Price => OrderQueue))) orderQueues;
    mapping(OrderKey => Order) orders;

    event PairAdded(PairKey indexed pairKey, Account maker, Token indexed base, Token indexed quote, uint8 baseDecimals, uint8 quoteDecimals, Factors factors, uint timestamp);
    event OrderAdded(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens tokens, Tokens quoteTokens, uint timestamp);
    event OrderRemoved(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Tokens tokens, uint timestamp);
    event OrderUpdated(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens tokens, uint timestamp);
    event Trade(TradeResult tradeResult);
    event TradeSummary(PairKey indexed pairKey, Account indexed taker, BuySell buySell, Price price, Tokens tokens, Tokens quoteTokens, Tokens tokensOnOrder, uint timestamp);

    error CannotRemoveMissingOrder();
    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Tokens tokens, Tokens tokensMax);
    error CannotInsertDuplicateOrder(OrderKey orderKey);
    error TransferFromFailedApproval(Token token, Account from, Account to, uint _tokens, uint _approved);
    error TransferFromFailed(Token token, Account from, Account to, uint _tokens);
    error InsufficientTokenBalanceOrAllowance(Token base, Tokens tokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(Token quote, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens unfilled);
    error UnableToBuyBelowTargetPrice(Price price, Price targetPrice);
    error UnableToSellAboveTargetPrice(Price price, Price targetPrice);
    error OrderNotFoundForUpdate(OrderKey orderKey);
    error OnlyPositiveTokensAccepted(Tokens tokens);

    function pair(uint i) public view returns (PairKey pairKey, Token base, Token quote, Factors memory factors) {
        pairKey = pairKeys[i];
        Pair memory p = pairs[pairKey];
        return (pairKey, p.base, p.quote, p.factors);
    }
    function pairsLength() public view returns (uint) {
        return pairKeys.length;
    }
    function getOrderQueue(PairKey pairKey, BuySell buySell, Price price) public view returns (OrderKey head, OrderKey tail) {
        OrderQueue memory orderQueue = orderQueues[pairKey][buySell][price];
        return (orderQueue.head, orderQueue.tail);
    }
    function getOrder(OrderKey orderKey) public view returns (OrderKey _next, Account maker, Unixtime expiry, Tokens tokens) {
        Order memory order = orders[orderKey];
        return (order.next, order.maker, order.expiry, order.tokens);
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
    function getMatchingBestPrice(MoreInfo memory moreInfo) internal view returns (Price price) {
        price = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].last() : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].first();
    }
    function getMatchingNextBestPrice(MoreInfo memory moreInfo, Price x) internal view returns (Price y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(x)) {
            y = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].last() : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].first();
        } else {
            y = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].prev(x) : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].next(x);
        }
    }

    function isSentinel(OrderKey orderKey) internal pure returns (bool) {
        return OrderKey.unwrap(orderKey) == OrderKey.unwrap(ORDERKEY_SENTINEL);
    }
    function isNotSentinel(OrderKey orderKey) internal pure returns (bool) {
        return OrderKey.unwrap(orderKey) != OrderKey.unwrap(ORDERKEY_SENTINEL);
    }
    function exists(OrderKey key) internal view returns (bool) {
        return Account.unwrap(orders[key].maker) != address(0);
    }
    function inverseBuySell(BuySell buySell) internal pure returns (BuySell inverse) {
        inverse = (buySell == BuySell.Buy) ? BuySell.Sell : BuySell.Buy;
    }
    function generatePairKey(TradeInput memory info) internal view returns (PairKey) {
        return PairKey.wrap(keccak256(abi.encodePacked(this, info.base, info.quote)));
    }
    function generateOrderKey(Account maker, BuySell buySell, Token base, Token quote, Price price) internal view returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(this, maker, buySell, base, quote, price)));
    }

    // Price:
    // Want to allow 0.000 111 111 111 which is 999 999 999 * 10^-12
    // Want to allow 999 999 999 000.0 which is 999 999 999 * 10^3
    // Want to represent by 999 999 999 * 10^-12 to 999 999 999 * 10^3

    // ERC-20
    // ONLY permit decimals from 0 to 24
    // Want to do token calculations on uint precision
    // Want to limit calculated range within a safe range

    // Can limit DEX trading Tokens, to limit the input

    // 2^16 = 65,536
    // 2^32 = 4,294,967,296
    // 2^48 = 281,474,976,710,656
    // 2^60 = 1, 152,921,504, 606,846,976
    // 2^64 = 18, 446,744,073,709,551,616
    // 2^128 = 340, 282,366,920,938,463,463, 374,607,431,768,211,456
    // 2^256 = 115,792, 089,237,316,195,423,570, 985,008,687,907,853,269, 984,665,640,564,039,457, 584,007,913,129,639,936
    // Price uint64 -> uint128 340, 282,366,920,938,463,463, 374,607,431,768,211,456
    //
    // Notes:
    //   quoteTokens = divisor * baseTokens * price / 10^9 / multiplier
    //   baseTokens = multiplier * quoteTokens * 10^9 / price / divisor
    //   price = multiplier * quoteTokens * 10^9 / baseTokens / divisor
    // Including the 10^9 with the multiplier:
    //   quoteTokens = divisor * baseTokens * price / multiplier
    //   baseTokens = multiplier * quoteTokens / price / divisor
    //   price = multiplier * quoteTokens / baseTokens / divisor

    function baseToQuote(Factors memory factors, uint tokens, Price price) pure internal returns (uint quoteTokens) {
        quoteTokens = uint128((10 ** Factor.unwrap(factors.divisor)) * tokens * uint(Price.unwrap(price)) / (10 ** Factor.unwrap(factors.multiplier)));
    }
    function quoteToBase(Factors memory factors, uint quoteTokens, Price price) pure internal returns (uint tokens) {
        tokens = (10 ** Factor.unwrap(factors.multiplier)) * quoteTokens / uint(Price.unwrap(price)) / (10 ** Factor.unwrap(factors.divisor));
    }
    function baseAndQuoteToPrice(Factors memory factors, uint tokens, uint quoteTokens) pure internal returns (Price price) {
        price = Price.wrap(uint128((10 ** Factor.unwrap(factors.multiplier)) * quoteTokens / tokens / (10 ** Factor.unwrap(factors.divisor))));
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


contract Dexz is DexzBase, ReentrancyGuard {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    function execute(TradeInput[] calldata tradeInputs) public {
        for (uint i = 0; i < tradeInputs.length; i = onePlus(i)) {
            TradeInput memory tradeInput = tradeInputs[i];
            if (uint(tradeInput.action) <= uint(Action.FillAnyAndAddOrder)) {
                if (Tokens.unwrap(tradeInput.tokens) < 0) {
                    revert OnlyPositiveTokensAccepted(tradeInput.tokens);
                }
                _trade(tradeInput, _getMoreInfo(tradeInput, Account.wrap(msg.sender)));
            } else if (tradeInput.action == Action.RemoveOrder) {
                _removeOrder(tradeInput, _getMoreInfo(tradeInput, Account.wrap(msg.sender)));
            } else if (tradeInput.action == Action.UpdateExpiryAndTokens) {
                _updateExpiryAndTokens(tradeInput, _getMoreInfo(tradeInput, Account.wrap(msg.sender)));
            }
        }
    }

    function _getMoreInfo(TradeInput memory tradeInput, Account taker) internal returns (MoreInfo memory moreInfo) {
        PairKey pairKey = generatePairKey(tradeInput);
        Factors memory factors;
        Pair memory pair = pairs[pairKey];
        if (Token.unwrap(pair.base) == address(0)) {
            uint8 baseDecimals = IERC20(Token.unwrap(tradeInput.base)).decimals();
            uint8 quoteDecimals = IERC20(Token.unwrap(tradeInput.quote)).decimals();
            // TODO Permit ERC-20 token decimals from 0 to 24
            // / 10^0 to / 10^24
            if (baseDecimals >= quoteDecimals) {
                factors.multiplier = Factor.wrap(baseDecimals - quoteDecimals + PRICE_DECIMALS);
                factors.divisor = Factor.wrap(0);
            } else {
                factors.multiplier = Factor.wrap(PRICE_DECIMALS);
                factors.divisor = Factor.wrap(quoteDecimals - baseDecimals);
            }
            pairs[pairKey] = Pair(tradeInput.base, tradeInput.quote, factors);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, Account.wrap(msg.sender), tradeInput.base, tradeInput.quote, baseDecimals, quoteDecimals, factors, block.timestamp);
        } else {
            factors.multiplier = pair.factors.multiplier;
            factors.divisor = pair.factors.divisor;
        }
        return MoreInfo(taker, inverseBuySell(tradeInput.buySell), pairKey, factors);
    }

    function _checkTakerAvailableTokens(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal view {
        // TODO: Check somewhere that tokens > 0
        if (tradeInput.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(tradeInput.quote, Account.wrap(msg.sender));
            uint quoteTokens = baseToQuote(moreInfo.factors, uint(uint128(Tokens.unwrap(tradeInput.tokens))), tradeInput.price);
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(tradeInput.quote, Tokens.wrap(int128(uint128(quoteTokens))), Tokens.wrap(int128(uint128(availableTokens))));
            }
        } else {
            uint availableTokens = availableTokens(tradeInput.base, Account.wrap(msg.sender));
            if (availableTokens < uint(uint128(Tokens.unwrap(tradeInput.tokens)))) {
                revert InsufficientTokenBalanceOrAllowance(tradeInput.base, tradeInput.tokens, Tokens.wrap(int128(uint128(availableTokens))));
            }
        }
    }

    struct StackTooDeepWorkaround {
        // uint availableTokens;
        bool deleteOrder;
        uint makerTokensToFill;
        uint tokensToTransfer;
        uint quoteTokensToTransfer;
    }

    event Debug(string name, uint value);

    function _trade(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (Tokens filled, Tokens quoteFilled, Tokens tokensOnOrder, OrderKey orderKey) {
        if (Price.unwrap(tradeInput.price) < Price.unwrap(PRICE_MIN) || Price.unwrap(tradeInput.price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(tradeInput.price, PRICE_MAX);
        }
        if (Tokens.unwrap(tradeInput.tokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(tradeInput.tokens, TOKENS_MAX);
        }
        // TODO - Decide whether to have this check _checkTakerAvailableTokens(tradeInput, moreInfo);

        Price bestMatchingPrice = getMatchingBestPrice(moreInfo);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
               ((tradeInput.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(tradeInput.price)) ||
                (tradeInput.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(tradeInput.price))) &&
               Tokens.unwrap(tradeInput.tokens) > 0) {
            OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][moreInfo.inverseBuySell][bestMatchingPrice];
            OrderKey bestMatchingOrderKey = orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey)) {
                Order storage order = orders[bestMatchingOrderKey];
                StackTooDeepWorkaround memory stdw;
                stdw.deleteOrder = false;
                if (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) >= block.timestamp) {
                    stdw.tokensToTransfer = 0;
                    stdw.quoteTokensToTransfer = 0;
                    if (tradeInput.buySell == BuySell.Buy) {
                        stdw.makerTokensToFill = uint(uint128(Tokens.unwrap(order.tokens)));
                        uint _availableTokens = availableTokens(tradeInput.base, order.maker);
                        if (_availableTokens > 0) {
                            if (stdw.makerTokensToFill > _availableTokens) {
                                stdw.makerTokensToFill = _availableTokens;
                            }
                            if (uint128(Tokens.unwrap(tradeInput.tokens)) >= stdw.makerTokensToFill) {
                                stdw.tokensToTransfer = stdw.makerTokensToFill;
                                stdw.deleteOrder = true;
                            } else {
                                stdw.tokensToTransfer = uint(uint128(Tokens.unwrap(tradeInput.tokens)));
                            }
                            stdw.quoteTokensToTransfer = baseToQuote(moreInfo.factors, stdw.tokensToTransfer, bestMatchingPrice);
                            if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
                                transferFrom(tradeInput.quote, moreInfo.taker, order.maker, stdw.quoteTokensToTransfer);
                                transferFrom(tradeInput.base, order.maker, moreInfo.taker, stdw.tokensToTransfer);
                            }
                            // emit Trade(moreInfo.pairKey, bestMatchingOrderKey, tradeInput.buySell, moreInfo.taker, order.maker, stdw.tokensToTransfer, stdw.quoteTokensToTransfer, bestMatchingPrice);
                            emit Trade(TradeResult(moreInfo.pairKey, bestMatchingOrderKey, moreInfo.taker, order.maker, tradeInput.buySell, bestMatchingPrice, stdw.tokensToTransfer, stdw.quoteTokensToTransfer, block.timestamp));
                        } else {
                            stdw.deleteOrder = true;
                        }
                    } else {
                        emit Debug("bestMatchingPrice", uint256(Price.unwrap(bestMatchingPrice)));
                        stdw.makerTokensToFill = uint(uint128(Tokens.unwrap(order.tokens)));
                        emit Debug("stdw.makerTokensToFill", stdw.makerTokensToFill);
                        uint availableQuoteTokens = availableTokens(tradeInput.quote, order.maker);
                        emit Debug("availableQuoteTokens", availableQuoteTokens);
                        if (availableQuoteTokens > 0) {
                            uint availableQuoteTokensInBaseTokens = quoteToBase(moreInfo.factors, availableQuoteTokens, bestMatchingPrice);
                            emit Debug("availableQuoteTokensInBaseTokens", availableQuoteTokensInBaseTokens);

                            if (stdw.makerTokensToFill > availableQuoteTokensInBaseTokens) {
                                stdw.makerTokensToFill = availableQuoteTokensInBaseTokens;
                            } else {
                                availableQuoteTokens = baseToQuote(moreInfo.factors, stdw.makerTokensToFill, bestMatchingPrice);
                            }

                            if (uint128(Tokens.unwrap(tradeInput.tokens)) >= stdw.makerTokensToFill) {
                                stdw.tokensToTransfer = stdw.makerTokensToFill;
                                stdw.quoteTokensToTransfer = availableQuoteTokens;
                                stdw.deleteOrder = true;
                            } else {
                                stdw.tokensToTransfer = uint(uint128(Tokens.unwrap(tradeInput.tokens)));
                                stdw.quoteTokensToTransfer = baseToQuote(moreInfo.factors, stdw.tokensToTransfer, bestMatchingPrice);
                            }

                            if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
                                transferFrom(tradeInput.base, moreInfo.taker, order.maker, stdw.tokensToTransfer);
                                transferFrom(tradeInput.quote, order.maker, moreInfo.taker, stdw.quoteTokensToTransfer);
                            }
                            emit Trade(TradeResult(moreInfo.pairKey, bestMatchingOrderKey, moreInfo.taker, order.maker, tradeInput.buySell, bestMatchingPrice, stdw.tokensToTransfer, stdw.quoteTokensToTransfer, block.timestamp));
                        } else {
                            stdw.deleteOrder = true;
                        }
                    }
                    order.tokens = Tokens.wrap(int128(uint128(Tokens.unwrap(order.tokens)) - uint128(stdw.tokensToTransfer)));
                    filled = Tokens.wrap(int128(uint128(Tokens.unwrap(filled)) + uint128(stdw.tokensToTransfer)));
                    quoteFilled = Tokens.wrap(int128(uint128(Tokens.unwrap(quoteFilled)) + uint128(stdw.quoteTokensToTransfer)));
                    tradeInput.tokens = Tokens.wrap(int128(uint128(Tokens.unwrap(tradeInput.tokens)) - uint128(stdw.tokensToTransfer)));
                } else {
                    stdw.deleteOrder = true;
                }
                if (stdw.deleteOrder) {
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
                if (Tokens.unwrap(tradeInput.tokens) == 0) {
                    break;
                }
            }
            if (isSentinel(orderQueue.head)) {
                delete orderQueues[moreInfo.pairKey][moreInfo.inverseBuySell][bestMatchingPrice];
                Price tempBestMatchingPrice = getMatchingNextBestPrice(moreInfo, bestMatchingPrice);
                BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell];
                if (priceTree.exists(bestMatchingPrice)) {
                    priceTree.remove(bestMatchingPrice);
                }
                bestMatchingPrice = tempBestMatchingPrice;
            } else {
                bestMatchingPrice = getMatchingNextBestPrice(moreInfo, bestMatchingPrice);
            }
        }
        if (tradeInput.action == Action.FillAllOrNothing) {
            if (Tokens.unwrap(tradeInput.tokens) > 0) {
                revert UnableToFillOrder(tradeInput.tokens);
            }
        }
        if (Tokens.unwrap(tradeInput.tokens) > 0 && (tradeInput.action == Action.FillAnyAndAddOrder)) {
            // TODO require(moreInfo.expiry > block.timestamp);
            orderKey = _addOrder(tradeInput, moreInfo);
            tokensOnOrder = tradeInput.tokens;
        }
        if (Tokens.unwrap(filled) > 0 || Tokens.unwrap(quoteFilled) > 0) {
            Price price = Tokens.unwrap(filled) > 0 ? baseAndQuoteToPrice(moreInfo.factors, uint(uint128(Tokens.unwrap(filled))), uint(uint128(Tokens.unwrap(quoteFilled)))) : Price.wrap(0);
            if (Price.unwrap(tradeInput.targetPrice) != 0) {
                if (tradeInput.buySell == BuySell.Buy) {
                    if (Price.unwrap(price) > Price.unwrap(tradeInput.targetPrice)) {
                        revert UnableToBuyBelowTargetPrice(price, tradeInput.targetPrice);
                    }
                } else {
                    if (Price.unwrap(price) < Price.unwrap(tradeInput.targetPrice)) {
                        revert UnableToSellAboveTargetPrice(price, tradeInput.targetPrice);
                    }
                }
            }
            emit TradeSummary(moreInfo.pairKey, moreInfo.taker, tradeInput.buySell, price, filled, quoteFilled, tokensOnOrder, block.timestamp);
            trades.push(TradeEvent(moreInfo.pairKey, moreInfo.taker, tradeInput.buySell, price, filled, quoteFilled, uint48(block.number), uint48(block.timestamp)));
        }
    }

    struct TradeEvent {
        PairKey pairKey; // bytes32
        Account taker; // address
        BuySell buySell; // uint8
        Price price; // uint128
        Tokens filled; // int128
        Tokens quoteFilled; // int128
        uint48 blockNumber; // 2^48 = 281,474,976,710,656
        uint48 timestamp; // 2^48 = 281,474,976,710,656
    }
    TradeEvent[] public trades;


    function _addOrder(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(moreInfo.taker, tradeInput.buySell, tradeInput.base, tradeInput.quote, tradeInput.price);
        if (Account.unwrap(orders[orderKey].maker) != address(0)) {
            revert CannotInsertDuplicateOrder(orderKey);
        }
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[moreInfo.pairKey][tradeInput.buySell];
        if (!priceTree.exists(tradeInput.price)) {
            priceTree.insert(tradeInput.price);
        }
        OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][tradeInput.buySell][tradeInput.price];
        if (isSentinel(orderQueue.head)) {
            orderQueues[moreInfo.pairKey][tradeInput.buySell][tradeInput.price] = OrderQueue(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            orderQueue = orderQueues[moreInfo.pairKey][tradeInput.buySell][tradeInput.price];
        }
        if (isSentinel(orderQueue.tail)) {
            orderQueue.head = orderKey;
            orderQueue.tail = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, moreInfo.taker, tradeInput.expiry, tradeInput.tokens);
        } else {
            orders[orderQueue.tail].next = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, moreInfo.taker, tradeInput.expiry, tradeInput.tokens);
            orderQueue.tail = orderKey;
        }
        uint quoteTokens = baseToQuote(moreInfo.factors, uint(uint128(Tokens.unwrap(tradeInput.tokens))), tradeInput.price);
        emit OrderAdded(moreInfo.pairKey, orderKey, moreInfo.taker, tradeInput.buySell, tradeInput.price, tradeInput.expiry, tradeInput.tokens, Tokens.wrap(int128(uint128(quoteTokens))), block.timestamp);
    }

    function _removeOrder(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][tradeInput.buySell][tradeInput.price];
        orderKey = orderQueue.head;
        OrderKey prevOrderKey;
        bool found;
        while (isNotSentinel(orderKey) && !found) {
            Order memory order = orders[orderKey];
            if (Account.unwrap(order.maker) == Account.unwrap(moreInfo.taker)) {
                OrderKey temp = orderKey;
                emit OrderRemoved(moreInfo.pairKey, orderKey, order.maker, tradeInput.buySell, tradeInput.price, order.tokens, block.timestamp);
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
                found = true;
            } else {
                prevOrderKey = orderKey;
                orderKey = order.next;
            }
        }
        if (found) {
            if (isSentinel(orderQueue.head)) {
                delete orderQueues[moreInfo.pairKey][tradeInput.buySell][tradeInput.price];
                BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[moreInfo.pairKey][tradeInput.buySell];
                if (priceTree.exists(tradeInput.price)) {
                    priceTree.remove(tradeInput.price);
                }
            }
        } else {
            revert CannotRemoveMissingOrder();
        }
    }

    function _updateExpiryAndTokens(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(moreInfo.taker, tradeInput.buySell, tradeInput.base, tradeInput.quote, tradeInput.price);
        Order storage order = orders[orderKey];
        if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
            revert OrderNotFoundForUpdate(orderKey);
        }
        order.tokens = Tokens.wrap(Tokens.unwrap(order.tokens) + Tokens.unwrap(tradeInput.tokens));
        if (Tokens.unwrap(order.tokens) < 0) {
            order.tokens = Tokens.wrap(0);
        }
        if (Tokens.unwrap(order.tokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(tradeInput.tokens, TOKENS_MAX);
        }
        // TODO - Decide whether to have this check _checkTakerAvailableTokens(tradeInput, moreInfo);
        order.expiry = tradeInput.expiry;
        emit OrderUpdated(moreInfo.pairKey, orderKey, moreInfo.taker, tradeInput.buySell, tradeInput.price, tradeInput.expiry, order.tokens, block.timestamp);
    }

    struct OrderResult {
        Price price;
        OrderKey orderKey;
        OrderKey nextOrderKey;
        Account maker;
        Unixtime expiry;
        Tokens tokens;
        Tokens availableBase;
        Tokens availableQuote;
    }
    function getOrders(PairKey pairKey, BuySell buySell, uint count, Price price, OrderKey firstOrderKey) public view returns (OrderResult[] memory orderResults) {
        orderResults = new OrderResult[](count);
        Pair memory pair = pairs[pairKey];
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
                uint availableBase;
                uint availableQuote;
                if (buySell == BuySell.Buy) {
                    availableQuote = availableTokens(pair.quote, order.maker);
                    availableBase = quoteToBase(pair.factors, availableQuote, price);
                } else {
                    availableBase = availableTokens(pair.base, order.maker);
                    availableQuote = baseToQuote(pair.factors, availableBase, price);
                }
                orderResults[i] = OrderResult(price, orderKey, order.next, order.maker, order.expiry, order.tokens, Tokens.wrap(int128(uint128(availableBase))), Tokens.wrap(int128(uint128(availableQuote))));
                orderKey = order.next;
                i = onePlus(i);
            }
            price = getNextBestPrice(pairKey, buySell, price);
        }
    }


    struct BestOrderResult {
        Price price;
        OrderKey orderKey;
        OrderKey nextOrderKey;
        Account maker;
        Unixtime expiry;
        Tokens tokens;
        Tokens availableBase;
        Tokens availableQuote;
    }
    function getBestOrder(PairKey pairKey, BuySell buySell) public view returns (BestOrderResult memory orderResult) {
        Pair memory pair = pairs[pairKey];
        Price price = getBestPrice(pairKey, buySell);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(price)) {
            OrderQueue memory orderQueue = orderQueues[pairKey][buySell][price];
            OrderKey orderKey = orderQueue.head;
            while (isNotSentinel(orderKey)) {
                Order memory order = orders[orderKey];
                uint availableBase;
                uint availableQuote;
                if (buySell == BuySell.Buy) {
                    availableQuote = availableTokens(pair.quote, order.maker);
                    availableBase = quoteToBase(pair.factors, availableQuote, price);
                } else {
                    availableBase = availableTokens(pair.base, order.maker);
                    availableQuote = baseToQuote(pair.factors, availableBase, price);
                }
                if (availableBase > 0 && availableQuote > 0 && (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) > block.timestamp)) {
                    orderResult = BestOrderResult(price, orderKey, order.next, order.maker, order.expiry, order.tokens, Tokens.wrap(int128(uint128(availableBase))), Tokens.wrap(int128(uint128(availableQuote))));
                    break;
                }
                orderKey = order.next;
            }
            if (Price.unwrap(orderResult.price) > 0) {
                break;
            }
            price = getNextBestPrice(pairKey, buySell, price);
        }
    }


    struct PairTokenResult {
        Token token;
        string symbol;
        string name;
        uint8 decimals;
    }
    struct PairResult {
        PairKey pairKey;
        PairTokenResult base;
        PairTokenResult quote;
        Factors factors;
        BestOrderResult bestBuyOrder;
        BestOrderResult bestSellOrder;
    }
    function getPair(uint i) public view returns (PairResult memory pairResult) {
        PairKey pairKey = pairKeys[i];
        Pair memory pair = pairs[pairKey];
        BestOrderResult memory bestBuyOrderResult = getBestOrder(pairKey, BuySell.Buy);
        BestOrderResult memory bestSellOrderResult = getBestOrder(pairKey, BuySell.Sell);
        pairResult = PairResult(pairKey,
            PairTokenResult(pair.base, IERC20(Token.unwrap(pair.base)).symbol(), IERC20(Token.unwrap(pair.base)).name(), IERC20(Token.unwrap(pair.base)).decimals()),
            PairTokenResult(pair.quote, IERC20(Token.unwrap(pair.quote)).symbol(), IERC20(Token.unwrap(pair.quote)).name(), IERC20(Token.unwrap(pair.quote)).decimals()),
            pair.factors, bestBuyOrderResult, bestSellOrderResult);
    }

    function getPairs(uint count, uint offset) public view returns (PairResult[] memory pairResults) {
        pairResults = new PairResult[](count);
        for (uint i = 0; i < count && ((i + offset) < pairKeys.length); i = onePlus(i)) {
            pairResults[i] = getPair(i + offset);
        }
    }
    function tradesLength() public view returns (uint) {
        return trades.length;
    }
    function getTradeEvents(uint count, uint offset) public view returns (TradeEvent[] memory results) {
        results = new TradeEvent[](count);
        for (uint i = 0; i < count && ((i + offset) < trades.length); i = onePlus(i)) {
            results[i] = trades[i + offset];
        }
    }

}
