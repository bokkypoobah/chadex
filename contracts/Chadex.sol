pragma solidity ^0.8.28;

import "./BokkyPooBahsRedBlackTreeLibrary.sol";

// ----------------------------------------------------------------------------
// Chadex v 0.8.9b-testing
//
// Deployed to Sepolia
//
// TODO:
//   * Check limits for Tokens(uint128) x Price(uint64) and conversions
//   * Check ccy1/ccy2 vs ccy2/ccy1?
//   * Check cost of taking vs making expired or dummy orders
//   * Serverless UI
//   * ?Move updated orders to the end of the queue
//   * ?computeTrade
//   * ?updatePriceExpiryAndTokens
//   * ?oracle
//   * ?Optional backend services
//
// https://github.com/bokkypoobah/Chadex
//
// SPDX-License-Identifier: MIT
//
// If you earn fees using your deployment of this code, or derivatives of this
// code, please send a proportionate amount to bokkypoobah.eth .
// Don't be stingy! Donations welcome!
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2024
// ----------------------------------------------------------------------------

// import "hardhat/console.sol";


type Account is address;  // 2^160
type Decimals is uint8;   // 2^8
type OrderKey is bytes32; // 2^256
type PairKey is bytes32;  // 2^256
type Token is address;    // 2^160
type Tokens is uint128;   // 2^128 = 340, 282,366,920,938,463,463, 374,607,431,768,211,456
type Unixtime is uint40;  // 2^40  = 1,099,511,627,776. For Unixtime, 1,099,511,627,776 seconds = 34865.285000507356672 years

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


contract ReentrancyGuard {
    bool transient lock;

    error ReentrancyAttempted();

    modifier reentrancyGuard() {
        require(!lock, ReentrancyAttempted());
        lock = true;
        _;
        lock = false;
    }
}


contract ChadexBase {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    struct Pair {
        Token[2] tokenz;       // 0: base, 1: quote
        Decimals[2] decimalss; // 0: base, 1: quote
    }
    struct OrderQueue {
        OrderKey head;   // 2^256
        OrderKey tail;   // 2^256
    }
    struct Order {
        OrderKey next;   // 2^256
        Account maker;   // 2^160
        Unixtime expiry; // 2^40
        Tokens tokens;   // 2^128
    }
    struct TradeInput {
        Action action;      // 2^8
        BuySell buySell;    // 2^8
        Token[2] tokenz;    // 2 x 2^160 - 0: base, 1: quote
        Price price;        // 2^64
        Price targetPrice;  // 2^64
        Unixtime expiry;    // 2^40
        Tokens tokens;      // 2^128
        bool skipCheck;     // ? 2^1
    }
    struct MoreInfo {
        Account taker;
        BuySell inverseBuySell;
        PairKey pairKey;
        Decimals[2] decimalss;  // 0: base, 1: quote
    }
    struct TradeResult {
        PairKey pairKey;
        OrderKey orderKey;
        Account taker;
        Account maker;
        BuySell buySell;
        Price price;
        Tokens baseTokens;
        Tokens quoteTokens;
        Unixtime timestamp;
    }

    uint8 public constant PRICE_DECIMALS = 9;
    Price public constant PRICE_EMPTY = Price.wrap(0);
    Price public constant PRICE_MIN = Price.wrap(1);
    Price public constant PRICE_MAX = Price.wrap(9_999_999_999_999_999_999); // 2^64 = 18, 446,744,073, 709,552,000
    Tokens public constant TOKENS_MIN = Tokens.wrap(0);
    Tokens public constant TOKENS_MAX = Tokens.wrap(999_999_999_999_999_999_999_999_999_999_999_999); // 2^128 = 340, 282,366,920, 938,463,463, 374,607,431, 768,211,456
    OrderKey public constant ORDERKEY_SENTINEL = OrderKey.wrap(0x0);
    Token constant THEDAO = Token.wrap(0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413);
    uint constant TOPIC_LENGTH_MAX = 48;
    uint constant TEXT_LENGTH_MAX = 280;

    PairKey[] public pairKeys;
    mapping(PairKey => Pair) pairs;
    mapping(PairKey => mapping(BuySell => BokkyPooBahsRedBlackTreeLibrary.Tree)) priceTrees;
    mapping(PairKey => mapping(BuySell => mapping(Price => OrderQueue))) orderQueues;
    mapping(OrderKey => Order) orders;

    event PairAdded(PairKey indexed pairKey, Account maker, Token indexed base, Token indexed quote, Decimals[2] decimalss, Unixtime timestamp);
    event OrderAdded(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens baseTokens, Tokens quoteTokens, Unixtime timestamp);
    event OrderRemoved(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Tokens baseTokens, Unixtime timestamp);
    event OrderUpdated(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens baseTokens, Unixtime timestamp);
    event Trade(TradeResult tradeResult);
    event TradeSummary(PairKey indexed pairKey, Account indexed taker, BuySell buySell, Price price, Tokens baseTokens, Tokens quoteTokens, Tokens tokensOnOrder, Unixtime timestamp);
    event Message(address indexed from, address indexed to, bytes32 indexed pairKey, bytes32 orderKey, string topic, string text, Unixtime timestamp);

    error CannotRemoveMissingOrder();
    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Tokens tokens, Tokens tokensMax);
    error CannotInsertDuplicateOrder(OrderKey orderKey);
    error TransferFromFailed(Token token, Account from, Account to, uint _tokens);
    error InsufficientTokenBalanceOrAllowance(Token token, Account tokenOwner, Tokens tokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(Token token, Account tokenOwner, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens unfilled);
    error UnableToBuyBelowTargetPrice(Price price, Price targetPrice);
    error UnableToSellAboveTargetPrice(Price price, Price targetPrice);
    error OrderNotFoundForUpdate(OrderKey orderKey);
    error InvalidMessageTopic(uint maxLength);
    error InvalidMessageText(uint maxLength);
    error CalculatedBaseTokensTooStrong(uint baseTokens, uint max);
    error CalculatedQuoteTokensTooStrong(uint quoteTokens, uint max);
    error CalculatedPriceTooStrong(uint price, uint max);
    error MaxTokenDecimals24(Decimals decimals); // TODO: Add token address if code size can be reduced

    function pair(uint i) public view returns (PairKey pairKey, Token[2] memory tokenz, Decimals[2] memory decimalss) {
        pairKey = pairKeys[i];
        Pair memory p = pairs[pairKey];
        return (pairKey, p.tokenz, p.decimalss);
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
        // inverse = BuySell(uint8(1) - uint8(buySell));
    }
    function generatePairKey(TradeInput memory info) internal view returns (PairKey) {
        return PairKey.wrap(keccak256(abi.encodePacked(this, info.tokenz)));
    }
    function generateOrderKey(Account maker, BuySell buySell, Token[2] memory tokenz, Price price) internal view returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(this, maker, buySell, tokenz, price)));
    }

    // ERC-20
    // ONLY permit decimals from 0 to 24
    // Want to do token calculations on uint precision
    // Want to limit calculated range within a safe range

    // 2^16 = 65,536
    // 2^32 = 4,294,967,296
    // 2^48 = 281,474,976,710,656
    // 2^60 = 1, 152,921,504, 606,846,976
    // 2^64 = 18, 446,744,073,709,551,616
    // 2^128 = 340, 282,366,920,938,463,463, 374,607,431,768,211,456
    // 2^256 = 115,792, 089,237,316,195,423,570, 985,008,687,907,853,269, 984,665,640,564,039,457, 584,007,913,129,639,936

    function baseToQuote(Decimals[2] memory decimalss, uint baseTokens, Price price) pure internal returns (uint quoteTokens) {
        // quoteTokens = divisor * baseTokens * price * 10^quoteDecimals / 10^9 / 10^baseDecimals
        quoteTokens = baseTokens * Price.unwrap(price) * 10**Decimals.unwrap(decimalss[1]) / 10**PRICE_DECIMALS / 10**Decimals.unwrap(decimalss[0]);
        if (quoteTokens >= uint(uint128(Tokens.unwrap(TOKENS_MAX)))) {
            revert CalculatedQuoteTokensTooStrong(quoteTokens, uint(uint128(Tokens.unwrap(TOKENS_MAX))));
        }
    }
    function quoteToBase(Decimals[2] memory decimalss, uint quoteTokens, Price price) pure internal returns (uint baseTokens) {
        //   baseTokens = quoteTokens * 10^9 * 10^baseDecimals / price / 10^quoteDecimals
        baseTokens = quoteTokens * 10**PRICE_DECIMALS * 10**Decimals.unwrap(decimalss[0]) / Price.unwrap(price) / 10**Decimals.unwrap(decimalss[1]);
        if (baseTokens >= uint(uint128(Tokens.unwrap(TOKENS_MAX)))) {
            revert CalculatedBaseTokensTooStrong(baseTokens, uint(uint128(Tokens.unwrap(TOKENS_MAX))));
        }
    }
    function baseAndQuoteToPrice(Decimals[2] memory decimalss, uint baseTokens, uint quoteTokens) pure internal returns (Price price) {
        //   price = quoteTokens * 10^9 * 10^baseDecimals / baseTokens / 10^quoteDecimals
        if (baseTokens > 0) {
            uint _price = quoteTokens * 10**PRICE_DECIMALS * 10**Decimals.unwrap(decimalss[0]) / baseTokens / 10**Decimals.unwrap(decimalss[1]);
            if (_price >= Price.unwrap(PRICE_MAX)) {
                revert CalculatedPriceTooStrong(_price, uint(Price.unwrap(PRICE_MAX)));
            }
            price = Price.wrap(uint64(_price));
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
    function decimals(Token token) internal view returns (Decimals _d) {
        if (Token.unwrap(token) == Token.unwrap(THEDAO)) {
            return Decimals.wrap(16);
        } else {
            try IERC20(Token.unwrap(token)).decimals() returns (uint8 __d) {
                _d = Decimals.wrap(__d);
            } catch {
                _d = Decimals.wrap(type(uint8).max);
            }
        }
    }
}


contract Chadex is ChadexBase, ReentrancyGuard {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    // struct TradeEvent {
    //     // OrderKey orderKey;
    //     Account taker; // address
    //     // Account maker; // address
    //     BuySell buySell; // uint8
    //     Price price; // uint128
    //     Tokens filled; // int128
    //     Tokens quoteFilled; // int128
    //     uint48 blockNumber; // 2^48 = 281,474,976,710,656
    //     Unixtime timestamp;
    // }

    // mapping(PairKey => TradeEvent[]) public trades;


    function execute(TradeInput[] calldata tradeInputs) public reentrancyGuard {
        for (uint i; i < tradeInputs.length; i++) {
            TradeInput memory tradeInput = tradeInputs[i];
            MoreInfo memory moreInfo = _getMoreInfo(tradeInput, Account.wrap(msg.sender));
            if (uint(tradeInput.action) <= uint(Action.FillAnyAndAddOrder)) {
                _trade(tradeInput, moreInfo);
            } else if (tradeInput.action == Action.RemoveOrder) {
                _removeOrder(tradeInput, moreInfo);
            } else if (tradeInput.action == Action.UpdateExpiryAndTokens) {
                _updateExpiryAndTokens(tradeInput, moreInfo);
            }
        }
    }

    function _getMoreInfo(TradeInput memory tradeInput, Account taker) internal returns (MoreInfo memory moreInfo) {
        PairKey pairKey = generatePairKey(tradeInput);
        Pair memory pair = pairs[pairKey];
        if (Token.unwrap(pair.tokenz[0]) == address(0)) {
            Decimals baseDecimals = decimals(tradeInput.tokenz[0]);
            Decimals quoteDecimals = decimals(tradeInput.tokenz[1]);
            if (Decimals.unwrap(baseDecimals) > 24) {
                revert MaxTokenDecimals24(baseDecimals);
            }
            if (Decimals.unwrap(quoteDecimals) > 24) {
                revert MaxTokenDecimals24(quoteDecimals);
            }
            pairs[pairKey] = Pair(tradeInput.tokenz, [baseDecimals, quoteDecimals]);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, taker, tradeInput.tokenz[0], tradeInput.tokenz[1], [baseDecimals, quoteDecimals], Unixtime.wrap(uint40(block.timestamp)));
        }
        return MoreInfo(taker, inverseBuySell(tradeInput.buySell), pairKey, pair.decimalss);
    }

    function _checkTakerAvailableTokens(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal view {
        if (tradeInput.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(tradeInput.tokenz[1], moreInfo.taker);
            uint quoteTokens = baseToQuote(moreInfo.decimalss, uint(uint128(Tokens.unwrap(tradeInput.tokens))), tradeInput.price);
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(tradeInput.tokenz[1], moreInfo.taker, Tokens.wrap(uint128(quoteTokens)), Tokens.wrap(uint128(availableTokens)));
            }
        } else {
            uint availableTokens = availableTokens(tradeInput.tokenz[0], moreInfo.taker);
            if (availableTokens < uint(uint128(Tokens.unwrap(tradeInput.tokens)))) {
                revert InsufficientTokenBalanceOrAllowance(tradeInput.tokenz[0], moreInfo.taker, tradeInput.tokens, Tokens.wrap(uint128(availableTokens)));
            }
        }
    }

    struct HandleOrderResults {
        bool deleteOrder;
        uint makerTokensToFill;
        uint tokensToTransfer;
        uint quoteTokensToTransfer;
    }
    function _handleOrder(TradeInput memory tradeInput, MoreInfo memory moreInfo, Price price, OrderKey orderKey, Order storage order) internal returns (HandleOrderResults memory vars) {
        bool deleteOrder;
        uint makerTokensToFill;
        uint tokensToTransfer;
        uint quoteTokensToTransfer;
        if (Unixtime.unwrap(order.expiry) != 0 && Unixtime.unwrap(order.expiry) < block.timestamp) {
            deleteOrder = true;
        } else {
            makerTokensToFill = uint(uint128(Tokens.unwrap(order.tokens)));
            if (tradeInput.buySell == BuySell.Buy) {
                uint _availableTokens = availableTokens(tradeInput.tokenz[0], order.maker);
                if (_availableTokens > 0) {
                    if (makerTokensToFill > _availableTokens) {
                        makerTokensToFill = _availableTokens;
                    }
                    if (uint128(Tokens.unwrap(tradeInput.tokens)) >= makerTokensToFill) {
                        tokensToTransfer = makerTokensToFill;
                        deleteOrder = true;
                    } else {
                        tokensToTransfer = uint(uint128(Tokens.unwrap(tradeInput.tokens)));
                    }
                    quoteTokensToTransfer = baseToQuote(moreInfo.decimalss, tokensToTransfer, price);
                    if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
                        transferFrom(tradeInput.tokenz[1], moreInfo.taker, order.maker, quoteTokensToTransfer);
                        transferFrom(tradeInput.tokenz[0], order.maker, moreInfo.taker, tokensToTransfer);
                    }
                    emit Trade(TradeResult(moreInfo.pairKey, orderKey, moreInfo.taker, order.maker, tradeInput.buySell, price, Tokens.wrap(uint128(tokensToTransfer)), Tokens.wrap(uint128(quoteTokensToTransfer)), Unixtime.wrap(uint40(block.timestamp))));
                    // trades.push(TradeEvent(moreInfo.pairKey, orderKey, moreInfo.taker, order.maker, tradeInput.buySell, price, Tokens.wrap(int128(uint128(tokensToTransfer))), Tokens.wrap(int128(uint128(quoteTokensToTransfer))), uint48(block.number), uint48(block.timestamp)));
                } else {
                    deleteOrder = true;
                }
            } else {
                uint availableQuoteTokens = availableTokens(tradeInput.tokenz[1], order.maker);
                if (availableQuoteTokens > 0) {
                    uint availableQuoteTokensInBaseTokens = quoteToBase(moreInfo.decimalss, availableQuoteTokens, price);
                    if (makerTokensToFill > availableQuoteTokensInBaseTokens) {
                        makerTokensToFill = availableQuoteTokensInBaseTokens;
                    } else {
                        availableQuoteTokens = baseToQuote(moreInfo.decimalss, makerTokensToFill, price);
                    }
                    if (uint128(Tokens.unwrap(tradeInput.tokens)) >= makerTokensToFill) {
                        tokensToTransfer = makerTokensToFill;
                        quoteTokensToTransfer = availableQuoteTokens;
                        deleteOrder = true;
                    } else {
                        tokensToTransfer = uint(uint128(Tokens.unwrap(tradeInput.tokens)));
                        quoteTokensToTransfer = baseToQuote(moreInfo.decimalss, tokensToTransfer, price);
                    }
                    if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
                        transferFrom(tradeInput.tokenz[0], moreInfo.taker, order.maker, tokensToTransfer);
                        transferFrom(tradeInput.tokenz[1], order.maker, moreInfo.taker, quoteTokensToTransfer);
                    }
                    emit Trade(TradeResult(moreInfo.pairKey, orderKey, moreInfo.taker, order.maker, tradeInput.buySell, price, Tokens.wrap(uint128(tokensToTransfer)), Tokens.wrap(uint128(quoteTokensToTransfer)), Unixtime.wrap(uint40(block.timestamp))));
                    // trades.push(TradeEvent(moreInfo.pairKey, orderKey, moreInfo.taker, order.maker, tradeInput.buySell, price, Tokens.wrap(int128(uint128(tokensToTransfer))), Tokens.wrap(int128(uint128(quoteTokensToTransfer))), uint48(block.number), uint48(block.timestamp)));
                } else {
                    deleteOrder = true;
                }
            }
        }
        return HandleOrderResults(deleteOrder, makerTokensToFill, tokensToTransfer, quoteTokensToTransfer);
    }

    function _trade(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (Tokens filled, Tokens quoteFilled, Tokens tokensOnOrder, OrderKey orderKey) {
        if (Price.unwrap(tradeInput.price) < Price.unwrap(PRICE_MIN) || Price.unwrap(tradeInput.price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(tradeInput.price, PRICE_MAX);
        }
        if (Tokens.unwrap(tradeInput.tokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(tradeInput.tokens, TOKENS_MAX);
        }
        if (!tradeInput.skipCheck) {
            _checkTakerAvailableTokens(tradeInput, moreInfo);
        }
        Price bestMatchingPrice = getMatchingBestPrice(moreInfo);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
               ((tradeInput.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(tradeInput.price)) ||
                (tradeInput.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(tradeInput.price))) &&
               Tokens.unwrap(tradeInput.tokens) > 0) {
            OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][moreInfo.inverseBuySell][bestMatchingPrice];
            OrderKey bestMatchingOrderKey = orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey)) {
                Order storage order = orders[bestMatchingOrderKey];
                HandleOrderResults memory results = _handleOrder(tradeInput, moreInfo, bestMatchingPrice, bestMatchingOrderKey, order);
                order.tokens = Tokens.wrap(uint128(Tokens.unwrap(order.tokens) - uint128(results.tokensToTransfer)));
                filled = Tokens.wrap(uint128(Tokens.unwrap(filled) + uint128(results.tokensToTransfer)));
                quoteFilled = Tokens.wrap(uint128(Tokens.unwrap(quoteFilled) + uint128(results.quoteTokensToTransfer)));
                tradeInput.tokens = Tokens.wrap(uint128(Tokens.unwrap(tradeInput.tokens) - uint128(results.tokensToTransfer)));
                if (results.deleteOrder) {
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
            orderKey = _addOrder(tradeInput, moreInfo);
            tokensOnOrder = tradeInput.tokens;
        }
        if (Tokens.unwrap(filled) > 0 || Tokens.unwrap(quoteFilled) > 0) {
            Price price = Tokens.unwrap(filled) > 0 ? baseAndQuoteToPrice(moreInfo.decimalss, uint(uint128(Tokens.unwrap(filled))), uint(uint128(Tokens.unwrap(quoteFilled)))) : Price.wrap(0);
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
            emit TradeSummary(moreInfo.pairKey, moreInfo.taker, tradeInput.buySell, price, filled, quoteFilled, tokensOnOrder, Unixtime.wrap(uint40(block.timestamp)));
            // trades[moreInfo.pairKey].push(TradeEvent(moreInfo.taker, tradeInput.buySell, price, filled, quoteFilled, uint48(block.number), uint48(block.timestamp)));
        }
    }

    function _addOrder(TradeInput memory tradeInput, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(moreInfo.taker, tradeInput.buySell, tradeInput.tokenz, tradeInput.price);
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
        uint quoteTokens = baseToQuote(moreInfo.decimalss, uint(uint128(Tokens.unwrap(tradeInput.tokens))), tradeInput.price);
        emit OrderAdded(moreInfo.pairKey, orderKey, moreInfo.taker, tradeInput.buySell, tradeInput.price, tradeInput.expiry, tradeInput.tokens, Tokens.wrap(uint128(quoteTokens)), Unixtime.wrap(uint40(block.timestamp)));
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
                emit OrderRemoved(moreInfo.pairKey, orderKey, order.maker, tradeInput.buySell, tradeInput.price, order.tokens, Unixtime.wrap(uint40(block.timestamp)));
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
        orderKey = generateOrderKey(moreInfo.taker, tradeInput.buySell, tradeInput.tokenz, tradeInput.price);
        Order storage order = orders[orderKey];
        if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
            revert OrderNotFoundForUpdate(orderKey);
        }
        // order.tokens = Tokens.wrap(Tokens.unwrap(order.tokens) + Tokens.unwrap(tradeInput.tokens));
        order.tokens = tradeInput.tokens;
        // if (Tokens.unwrap(order.tokens) < 0) {
        //     order.tokens = Tokens.wrap(0);
        // }
        if (Tokens.unwrap(order.tokens) > Tokens.unwrap(TOKENS_MAX)) {
            revert InvalidTokens(tradeInput.tokens, TOKENS_MAX);
        }
        if (!tradeInput.skipCheck) {
            _checkTakerAvailableTokens(tradeInput, moreInfo);
        }
        order.expiry = tradeInput.expiry;
        emit OrderUpdated(moreInfo.pairKey, orderKey, moreInfo.taker, tradeInput.buySell, tradeInput.price, tradeInput.expiry, order.tokens, Unixtime.wrap(uint40(block.timestamp)));
    }

    /// @dev Send message
    /// @param to Destination address, or address(0) for general messages
    /// @param pairKey Key to specific pair, or bytes32(0) for no specific pair
    /// @param orderKey Key to specific order, or bytes32(0) for no specific order
    /// @param topic Message topic. Length between 0 and `TOPIC_LENGTH_MAX`
    /// @param text Message text. Length between 1 and `TEXT_LENGTH_MAX`
    function sendMessage(address to, bytes32 pairKey, bytes32 orderKey, string calldata topic, string calldata text) public {
        bytes memory topicBytes = bytes(topic);
        if (topicBytes.length > TOPIC_LENGTH_MAX) {
            revert InvalidMessageTopic(TOPIC_LENGTH_MAX);
        }
        bytes memory textBytes = bytes(text);
        if (textBytes.length < 1 || textBytes.length > TEXT_LENGTH_MAX) {
            revert InvalidMessageText(TEXT_LENGTH_MAX);
        }
        // if (pairKey != bytes32(0) && !umswapExists[bytes32] && !isERC721(umswapOrCollection)) {
        //     revert InvalidUmswapOrCollection();
        // }
        emit Message(msg.sender, to, pairKey, orderKey, topic, text, Unixtime.wrap(uint40(block.timestamp)));
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
                    availableQuote = availableTokens(pair.tokenz[1], order.maker);
                    availableBase = quoteToBase(pair.decimalss, availableQuote, price);
                } else {
                    availableBase = availableTokens(pair.tokenz[0], order.maker);
                    availableQuote = baseToQuote(pair.decimalss, availableBase, price);
                }
                orderResults[i] = OrderResult(price, orderKey, order.next, order.maker, order.expiry, order.tokens, Tokens.wrap(uint128(availableBase)), Tokens.wrap(uint128(availableQuote)));
                orderKey = order.next;
                i++;
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
                    availableQuote = availableTokens(pair.tokenz[1], order.maker);
                    availableBase = quoteToBase(pair.decimalss, availableQuote, price);
                } else {
                    availableBase = availableTokens(pair.tokenz[0], order.maker);
                    availableQuote = baseToQuote(pair.decimalss, availableBase, price);
                }
                if (availableBase > 0 && availableQuote > 0 && (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) > block.timestamp)) {
                    orderResult = BestOrderResult(price, orderKey, order.next, order.maker, order.expiry, order.tokens, Tokens.wrap(uint128(availableBase)), Tokens.wrap(uint128(availableQuote)));
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


    struct PairResult {
        PairKey pairKey;
        Token[2] tokenz;
        Decimals[2] decimalss;
        BestOrderResult bestBuyOrder;
        BestOrderResult bestSellOrder;
    }
    function getPair(uint i) public view returns (PairResult memory pairResult) {
        PairKey pairKey = pairKeys[i];
        Pair memory pair = pairs[pairKey];
        BestOrderResult memory bestBuyOrderResult = getBestOrder(pairKey, BuySell.Buy);
        BestOrderResult memory bestSellOrderResult = getBestOrder(pairKey, BuySell.Sell);
        pairResult = PairResult(pairKey, pair.tokenz, pair.decimalss, bestBuyOrderResult, bestSellOrderResult);
    }
    function getPairs(uint count, uint offset) public view returns (PairResult[] memory pairResults) {
        pairResults = new PairResult[](count);
        for (uint i; i < count && ((i + offset) < pairKeys.length); i++) {
            pairResults[i] = getPair(i + offset);
        }
    }

    // function tradesLength(PairKey pairKey) public view returns (uint) {
    //     return trades[pairKey].length;
    // }
    // function getTradeEvents(PairKey pairKey, uint count, uint offset) public view returns (TradeEvent[] memory results) {
    //     results = new TradeEvent[](count);
    //     for (uint i; i < count && ((i + offset) < trades[pairKey].length); i++) {
    //         results[i] = trades[pairKey][i + offset];
    //     }
    // }

    // struct TokenInfoResult {
    //     string symbol;
    //     string name;
    //     uint8 decimals;
    //     Tokens totalSupply;
    // }
    // function getTokenInfo(Token[] memory tokens) public view returns (TokenInfoResult[] memory results) {
    //     results = new TokenInfoResult[](tokens.length);
    //     for (uint i; i < tokens.length; i++) {
    //         IERC20 t = IERC20(Token.unwrap(tokens[i]));
    //         results[i] = TokenInfoResult(t.symbol(), t.name(), t.decimals(), Tokens.wrap(int128(uint128(t.totalSupply()))));
    //     }
    // }

    struct TokenBalanceAndAllowanceResult {
        Tokens balance;
        Tokens allowance;
    }
    function getTokenBalanceAndAllowance(Account[] memory owners, Token[] memory tokens) public view returns (TokenBalanceAndAllowanceResult[] memory results) {
        require(owners.length == tokens.length);
        results = new TokenBalanceAndAllowanceResult[](owners.length);
        for (uint i; i < owners.length; i++) {
            IERC20 t = IERC20(Token.unwrap(tokens[i]));
            results[i] = TokenBalanceAndAllowanceResult(Tokens.wrap(uint128(t.allowance(Account.unwrap(owners[i]), address(this)))), Tokens.wrap(uint128(t.balanceOf(Account.unwrap(owners[i])))));
        }
    }
}
