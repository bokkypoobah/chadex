pragma solidity ^0.8.0;

// ----------------------------------------------------------------------------
// BokkyPooBah's Red-Black Tree Library v1.0-pre-release-a
//
// A Solidity Red-Black Tree binary search library to store and access a sorted
// list of unsigned integer data. The Red-Black algorithm rebalances the binary
// search tree, resulting in O(log n) insert, remove and search time (and ~gas)
//
// https://github.com/bokkypoobah/BokkyPooBahsRedBlackTreeLibrary
//
// SPDX-License-Identifier: MIT
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2020. The MIT Licence.
// ----------------------------------------------------------------------------
type Price is uint64;

library BokkyPooBahsRedBlackTreeLibrary {

    struct Node {
        Price parent;
        Price left;
        Price right;
        uint8 red;
    }

    struct Tree {
        Price root;
        mapping(Price => Node) nodes;
    }

    Price private constant EMPTY = Price.wrap(0);
    uint8 private constant RED_TRUE = 1;
    uint8 private constant RED_FALSE = 2; // Can also be 0 - check against RED_TRUE

    error CannotFindNextEmptyKey();
    error CannotFindPrevEmptyKey();
    error CannotInsertEmptyKey();
    error CannotInsertExistingKey();
    error CannotRemoveEmptyKey();
    error CannotRemoveMissingKey();

    function first(Tree storage self) internal view returns (Price key) {
        key = self.root;
        if (isNotEmpty(key)) {
            while (isNotEmpty(self.nodes[key].left)) {
                key = self.nodes[key].left;
            }
        }
    }
    function last(Tree storage self) internal view returns (Price key) {
        key = self.root;
        if (isNotEmpty(key)) {
            while (isNotEmpty(self.nodes[key].right)) {
                key = self.nodes[key].right;
            }
        }
    }
    function next(Tree storage self, Price target) internal view returns (Price cursor) {
        if (isEmpty(target)) {
            revert CannotFindNextEmptyKey();
        }
        if (isNotEmpty(self.nodes[target].right)) {
            cursor = treeMinimum(self, self.nodes[target].right);
        } else {
            cursor = self.nodes[target].parent;
            while (isNotEmpty(cursor) && Price.unwrap(target) == Price.unwrap(self.nodes[cursor].right)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function prev(Tree storage self, Price target) internal view returns (Price cursor) {
        if (isEmpty(target)) {
            revert CannotFindPrevEmptyKey();
        }
        if (isNotEmpty(self.nodes[target].left)) {
            cursor = treeMaximum(self, self.nodes[target].left);
        } else {
            cursor = self.nodes[target].parent;
            while (isNotEmpty(cursor) && Price.unwrap(target) == Price.unwrap(self.nodes[cursor].left)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function exists(Tree storage self, Price key) internal view returns (bool) {
        return isNotEmpty(key) && ((Price.unwrap(key) == Price.unwrap(self.root)) || isNotEmpty(self.nodes[key].parent));
    }
    function isEmpty(Price key) internal pure returns (bool) {
        return Price.unwrap(key) == Price.unwrap(EMPTY);
    }
    function isNotEmpty(Price key) internal pure returns (bool) {
        return Price.unwrap(key) != Price.unwrap(EMPTY);
    }
    function getEmpty() internal pure returns (Price) {
        return EMPTY;
    }
    function getNode(Tree storage self, Price key) internal view returns (Price returnKey, Price parent, Price left, Price right, uint8 red) {
        require(exists(self, key));
        return(key, self.nodes[key].parent, self.nodes[key].left, self.nodes[key].right, self.nodes[key].red);
    }

    function insert(Tree storage self, Price key) internal {
        if (isEmpty(key)) {
            revert CannotInsertEmptyKey();
        }
        if (exists(self, key)) {
            revert CannotInsertExistingKey();
        }
        Price cursor = EMPTY;
        Price probe = self.root;
        while (isNotEmpty(probe)) {
            cursor = probe;
            if (Price.unwrap(key) < Price.unwrap(probe)) {
                probe = self.nodes[probe].left;
            } else {
                probe = self.nodes[probe].right;
            }
        }
        self.nodes[key] = Node({parent: cursor, left: EMPTY, right: EMPTY, red: RED_TRUE});
        if (isEmpty(cursor)) {
            self.root = key;
        } else if (Price.unwrap(key) < Price.unwrap(cursor)) {
            self.nodes[cursor].left = key;
        } else {
            self.nodes[cursor].right = key;
        }
        insertFixup(self, key);
    }
    function remove(Tree storage self, Price key) internal {
        if (isEmpty(key)) {
            revert CannotRemoveEmptyKey();
        }
        if (!exists(self, key)) {
            revert CannotRemoveMissingKey();
        }
        Price probe;
        Price cursor;
        if (isEmpty(self.nodes[key].left) || isEmpty(self.nodes[key].right)) {
            cursor = key;
        } else {
            cursor = self.nodes[key].right;
            while (isNotEmpty(self.nodes[cursor].left)) {
                cursor = self.nodes[cursor].left;
            }
        }
        if (isNotEmpty(self.nodes[cursor].left)) {
            probe = self.nodes[cursor].left;
        } else {
            probe = self.nodes[cursor].right;
        }
        Price yParent = self.nodes[cursor].parent;
        self.nodes[probe].parent = yParent;
        if (isNotEmpty(yParent)) {
            if (Price.unwrap(cursor) == Price.unwrap(self.nodes[yParent].left)) {
                self.nodes[yParent].left = probe;
            } else {
                self.nodes[yParent].right = probe;
            }
        } else {
            self.root = probe;
        }
        bool doFixup = self.nodes[cursor].red != RED_TRUE;
        if (Price.unwrap(cursor) != Price.unwrap(key)) {
            replaceParent(self, cursor, key);
            self.nodes[cursor].left = self.nodes[key].left;
            self.nodes[self.nodes[cursor].left].parent = cursor;
            self.nodes[cursor].right = self.nodes[key].right;
            self.nodes[self.nodes[cursor].right].parent = cursor;
            self.nodes[cursor].red = self.nodes[key].red;
            (cursor, key) = (key, cursor);
        }
        if (doFixup) {
            removeFixup(self, probe);
        }
        delete self.nodes[cursor];
    }

    function treeMinimum(Tree storage self, Price key) private view returns (Price) {
        while (isNotEmpty(self.nodes[key].left)) {
            key = self.nodes[key].left;
        }
        return key;
    }
    function treeMaximum(Tree storage self, Price key) private view returns (Price) {
        while (isNotEmpty(self.nodes[key].right)) {
            key = self.nodes[key].right;
        }
        return key;
    }

    function rotateLeft(Tree storage self, Price key) private {
        Price cursor = self.nodes[key].right;
        Price keyParent = self.nodes[key].parent;
        Price cursorLeft = self.nodes[cursor].left;
        self.nodes[key].right = cursorLeft;
        if (isNotEmpty(cursorLeft)) {
            self.nodes[cursorLeft].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (isEmpty(keyParent)) {
            self.root = cursor;
        } else if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
            self.nodes[keyParent].left = cursor;
        } else {
            self.nodes[keyParent].right = cursor;
        }
        self.nodes[cursor].left = key;
        self.nodes[key].parent = cursor;
    }
    function rotateRight(Tree storage self, Price key) private {
        Price cursor = self.nodes[key].left;
        Price keyParent = self.nodes[key].parent;
        Price cursorRight = self.nodes[cursor].right;
        self.nodes[key].left = cursorRight;
        if (isNotEmpty(cursorRight)) {
            self.nodes[cursorRight].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (isEmpty(keyParent)) {
            self.root = cursor;
        } else if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].right)) {
            self.nodes[keyParent].right = cursor;
        } else {
            self.nodes[keyParent].left = cursor;
        }
        self.nodes[cursor].right = key;
        self.nodes[key].parent = cursor;
    }

    function insertFixup(Tree storage self, Price key) private {
        Price cursor;
        while (Price.unwrap(key) != Price.unwrap(self.root) && self.nodes[self.nodes[key].parent].red == RED_TRUE) {
            Price keyParent = self.nodes[key].parent;
            if (Price.unwrap(keyParent) == Price.unwrap(self.nodes[self.nodes[keyParent].parent].left)) {
                cursor = self.nodes[self.nodes[keyParent].parent].right;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    key = self.nodes[keyParent].parent;
                } else {
                    if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].right)) {
                      key = keyParent;
                      rotateLeft(self, key);
                    }
                    keyParent = self.nodes[key].parent;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    rotateRight(self, self.nodes[keyParent].parent);
                }
            } else {
                cursor = self.nodes[self.nodes[keyParent].parent].left;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    key = self.nodes[keyParent].parent;
                } else {
                    if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
                      key = keyParent;
                      rotateRight(self, key);
                    }
                    keyParent = self.nodes[key].parent;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    rotateLeft(self, self.nodes[keyParent].parent);
                }
            }
        }
        self.nodes[self.root].red = RED_FALSE;
    }

    function replaceParent(Tree storage self, Price a, Price b) private {
        Price bParent = self.nodes[b].parent;
        self.nodes[a].parent = bParent;
        if (isEmpty(bParent)) {
            self.root = a;
        } else {
            if (Price.unwrap(b) == Price.unwrap(self.nodes[bParent].left)) {
                self.nodes[bParent].left = a;
            } else {
                self.nodes[bParent].right = a;
            }
        }
    }
    function removeFixup(Tree storage self, Price key) private {
        Price cursor;
        while (Price.unwrap(key) != Price.unwrap(self.root) && self.nodes[key].red != RED_TRUE) {
            Price keyParent = self.nodes[key].parent;
            if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
                cursor = self.nodes[keyParent].right;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[keyParent].red = RED_TRUE;
                    rotateLeft(self, keyParent);
                    cursor = self.nodes[keyParent].right;
                }
                if (self.nodes[self.nodes[cursor].left].red != RED_TRUE && self.nodes[self.nodes[cursor].right].red != RED_TRUE) {
                    self.nodes[cursor].red = RED_TRUE;
                    key = keyParent;
                } else {
                    if (self.nodes[self.nodes[cursor].right].red != RED_TRUE) {
                        self.nodes[self.nodes[cursor].left].red = RED_FALSE;
                        self.nodes[cursor].red = RED_TRUE;
                        rotateRight(self, cursor);
                        cursor = self.nodes[keyParent].right;
                    }
                    self.nodes[cursor].red = self.nodes[keyParent].red;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[cursor].right].red = RED_FALSE;
                    rotateLeft(self, keyParent);
                    key = self.root;
                }
            } else {
                cursor = self.nodes[keyParent].left;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[keyParent].red = RED_TRUE;
                    rotateRight(self, keyParent);
                    cursor = self.nodes[keyParent].left;
                }
                if (self.nodes[self.nodes[cursor].right].red != RED_TRUE && self.nodes[self.nodes[cursor].left].red != RED_TRUE) {
                    self.nodes[cursor].red = RED_TRUE;
                    key = keyParent;
                } else {
                    if (self.nodes[self.nodes[cursor].left].red != RED_TRUE) {
                        self.nodes[self.nodes[cursor].right].red = RED_FALSE;
                        self.nodes[cursor].red = RED_TRUE;
                        rotateLeft(self, cursor);
                        cursor = self.nodes[keyParent].left;
                    }
                    self.nodes[cursor].red = self.nodes[keyParent].red;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[cursor].left].red = RED_FALSE;
                    rotateRight(self, keyParent);
                    key = self.root;
                }
            }
        }
        self.nodes[key].red = RED_FALSE;
    }
}
// ----------------------------------------------------------------------------
// End - BokkyPooBah's Red-Black Tree Library
// ----------------------------------------------------------------------------


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
//   * Check limits for Tokens(uint128) x Price(uint64)
//   * Review Delta and Token conversions
//   * Check cost of taking vs making expired or dummy orders
//   * Check remainder from divisions
//   * Serverless UI
//   * Move updated orders to the end of the queue?
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
    struct Info {
        Action action;
        BuySell buySell;
        Token base;
        Token quote;
        Price price;
        Unixtime expiry;
        Delta tokens;
    }
    struct MoreInfo {
        Account taker;
        BuySell inverseBuySell;
        PairKey pairKey;
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
    event OrderUpdated(PairKey indexed pairKey, OrderKey indexed orderKey, Account indexed maker, BuySell buySell, Price price, Unixtime expiry, Tokens tokens);
    event Trade(PairKey indexed pairKey, OrderKey indexed orderKey, BuySell buySell, Account indexed taker, Account maker, uint tokens, uint quoteTokens, Price price);
    event TradeSummary(BuySell buySell, Account indexed taker, Tokens filled, Tokens quoteTokensFilled, Price price, Tokens tokensOnOrder);

    error CannotRemoveMissingOrder();
    error InvalidPrice(Price price, Price priceMax);
    error InvalidTokens(Delta tokens, Tokens tokensMax);
    error CannotInsertDuplicateOrder(OrderKey orderKey);
    error TransferFromFailedApproval(Token token, Account from, Account to, uint _tokens, uint _approved);
    error TransferFromFailed(Token token, Account from, Account to, uint _tokens);
    error InsufficientTokenBalanceOrAllowance(Token base, Delta tokens, Tokens availableTokens);
    error InsufficientQuoteTokenBalanceOrAllowance(Token quote, Tokens quoteTokens, Tokens availableTokens);
    error UnableToFillOrder(Tokens unfilled);
    error OrderNotFoundForUpdate(OrderKey orderKey);
    error OnlyPositiveTokensAccepted(Delta tokens);


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

    function generatePairKey(Info memory info) internal pure returns (PairKey) {
        return PairKey.wrap(keccak256(abi.encodePacked(info.base, info.quote)));
    }
    function generateOrderKey(BuySell buySell, Account maker, Token base, Token quote, Price price) internal pure returns (OrderKey) {
        return OrderKey.wrap(keccak256(abi.encodePacked(buySell, maker, base, quote, price)));
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

    function getMatchingBestPrice(MoreInfo memory moreInfo) public view returns (Price price) {
        price = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].last() : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].first();
    }
    function getMatchingNextBestPrice(MoreInfo memory moreInfo, Price x) public view returns (Price y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(x)) {
            y = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].last() : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].first();
        } else {
            y = (moreInfo.inverseBuySell == BuySell.Buy) ? priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].prev(x) : priceTrees[moreInfo.pairKey][moreInfo.inverseBuySell].next(x);
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


contract Dexz is DexzBase, ReentrancyGuard {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    constructor() DexzBase() {
    }

    function execute(Info[] calldata infos) public {
        for (uint i = 0; i < infos.length; i = onePlus(i)) {
            Info memory info = infos[i];
            if (uint(info.action) <= uint(Action.FillAnyAndAddOrder)) {
                if (Delta.unwrap(info.tokens) < 0) {
                    revert OnlyPositiveTokensAccepted(info.tokens);
                }
                _trade(info, _getMoreInfo(info, Account.wrap(msg.sender)));
            } else if (info.action == Action.RemoveOrder) {
                _removeOrder(info, _getMoreInfo(info, Account.wrap(msg.sender)));
            } else if (info.action == Action.UpdateExpiryAndTokens) {
                _updateExpiryAndTokens(info, _getMoreInfo(info, Account.wrap(msg.sender)));
            }
        }
    }

    function _updateExpiryAndTokens(Info memory info, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        if (Delta.unwrap(info.tokens) > int128(Tokens.unwrap(TOKENS_MAX))) {
            revert InvalidTokens(info.tokens, TOKENS_MAX);
        }
        orderKey = generateOrderKey(info.buySell, moreInfo.taker, info.base, info.quote, info.price);
        Order storage order = orders[orderKey];
        if (Account.unwrap(order.maker) != Account.unwrap(moreInfo.taker)) {
            revert OrderNotFoundForUpdate(orderKey);
        }
        if (Delta.unwrap(info.tokens) < 0) {
            uint128 negativeTokens = uint128(-1 * Delta.unwrap(info.tokens));
            if (negativeTokens > (Tokens.unwrap(order.tokens) - Tokens.unwrap(order.filled))) {
                info.tokens = Delta.wrap(int128(Tokens.unwrap(order.filled)));
            } else {
                info.tokens = Delta.wrap(int128(Tokens.unwrap(order.tokens) - uint128(-1 * Delta.unwrap(info.tokens))));
            }
        } else {
            info.tokens = Delta.wrap(int128(Tokens.unwrap(order.tokens) + uint128(Delta.unwrap(info.tokens))));
        }
        Pair memory pair = pairs[moreInfo.pairKey];
        _checkTakerAvailableTokens(info, pair);
        order.tokens = Tokens.wrap(uint128(Delta.unwrap(info.tokens)));
        order.expiry = info.expiry;
        emit OrderUpdated(moreInfo.pairKey, orderKey, moreInfo.taker, info.buySell, info.price, info.expiry, order.tokens);
    }

    function _removeOrder(Info memory info, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][info.buySell][info.price];
        orderKey = orderQueue.head;
        OrderKey prevOrderKey;
        bool found;
        while (isNotSentinel(orderKey) && !found) {
            Order memory order = orders[orderKey];
            if (Account.unwrap(order.maker) == Account.unwrap(moreInfo.taker)) {
                OrderKey temp = orderKey;
                emit OrderRemoved(moreInfo.pairKey, orderKey, order.maker, info.buySell, info.price, order.tokens, order.filled);
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
                delete orderQueues[moreInfo.pairKey][info.buySell][info.price];
                BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[moreInfo.pairKey][info.buySell];
                if (priceTree.exists(info.price)) {
                    priceTree.remove(info.price);
                }
            }
        } else {
            revert CannotRemoveMissingOrder();
        }
    }

    function _getMoreInfo(Info memory info, Account taker) internal returns (MoreInfo memory moreInfo) {
        PairKey pairKey = generatePairKey(info);
        if (Token.unwrap(pairs[pairKey].base) == address(0)) {
            uint8 baseDecimals = IERC20(Token.unwrap(info.base)).decimals();
            uint8 quoteDecimals = IERC20(Token.unwrap(info.quote)).decimals();
            Factor multiplier;
            Factor divisor;
            if (baseDecimals >= quoteDecimals) {
                multiplier = Factor.wrap(baseDecimals - quoteDecimals + 9);
                divisor = Factor.wrap(0);
            } else {
                multiplier = Factor.wrap(9);
                divisor = Factor.wrap(quoteDecimals - baseDecimals);
            }
            pairs[pairKey] = Pair(info.base, info.quote, multiplier, divisor);
            pairKeys.push(pairKey);
            emit PairAdded(pairKey, info.base, info.quote, baseDecimals, quoteDecimals, multiplier, divisor);
        }
        return MoreInfo(taker, inverseBuySell(info.buySell), pairKey);
    }
    function _checkTakerAvailableTokens(Info memory info, Pair memory pair) internal view {
        // TODO: Check somewhere that tokens > 0
        if (info.buySell == BuySell.Buy) {
            uint availableTokens = availableTokens(pair.quote, Account.wrap(msg.sender));
            uint quoteTokens = (10 ** Factor.unwrap(pair.divisor)) * uint(uint128(Delta.unwrap(info.tokens))) * Price.unwrap(info.price) / (10 ** Factor.unwrap(pair.multiplier));
            if (availableTokens < quoteTokens) {
                revert InsufficientQuoteTokenBalanceOrAllowance(pair.quote, Tokens.wrap(uint128(quoteTokens)), Tokens.wrap(uint128(availableTokens)));
            }
        } else {
            uint availableTokens = availableTokens(pair.base, Account.wrap(msg.sender));
            if (availableTokens < uint(uint128(Delta.unwrap(info.tokens)))) {
                revert InsufficientTokenBalanceOrAllowance(pair.base, info.tokens, Tokens.wrap(uint128(availableTokens)));
            }
        }
    }
    function _addOrder(Info memory info, MoreInfo memory moreInfo) internal returns (OrderKey orderKey) {
        orderKey = generateOrderKey(info.buySell, moreInfo.taker, info.base, info.quote, info.price);
        if (Account.unwrap(orders[orderKey].maker) != address(0)) {
            revert CannotInsertDuplicateOrder(orderKey);
        }
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceTree = priceTrees[moreInfo.pairKey][info.buySell];
        if (!priceTree.exists(info.price)) {
            priceTree.insert(info.price);
        }
        OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][info.buySell][info.price];
        if (isSentinel(orderQueue.head)) {
            orderQueues[moreInfo.pairKey][info.buySell][info.price] = OrderQueue(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            orderQueue = orderQueues[moreInfo.pairKey][info.buySell][info.price];
        }
        if (isSentinel(orderQueue.tail)) {
            orderQueue.head = orderKey;
            orderQueue.tail = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, moreInfo.taker, info.expiry, Tokens.wrap(uint128(Delta.unwrap(info.tokens))), Tokens.wrap(0));
        } else {
            orders[orderQueue.tail].next = orderKey;
            orders[orderKey] = Order(ORDERKEY_SENTINEL, moreInfo.taker, info.expiry, Tokens.wrap(uint128(Delta.unwrap(info.tokens))), Tokens.wrap(0));
            orderQueue.tail = orderKey;
        }
        emit OrderAdded(moreInfo.pairKey, orderKey, moreInfo.taker, info.buySell, info.price, info.expiry, Tokens.wrap(uint128(Delta.unwrap(info.tokens))));
    }
    function _trade(Info memory info, MoreInfo memory moreInfo) internal returns (Tokens filled, Tokens quoteTokensFilled, Tokens tokensOnOrder, OrderKey orderKey) {
        if (Price.unwrap(info.price) < Price.unwrap(PRICE_MIN) || Price.unwrap(info.price) > Price.unwrap(PRICE_MAX)) {
            revert InvalidPrice(info.price, PRICE_MAX);
        }
        if (Delta.unwrap(info.tokens) > int128(Tokens.unwrap(TOKENS_MAX))) {
            revert InvalidTokens(info.tokens, TOKENS_MAX);
        }
        Pair memory pair = pairs[moreInfo.pairKey];
        _checkTakerAvailableTokens(info, pair);

        Price bestMatchingPrice = getMatchingBestPrice(moreInfo);
        while (BokkyPooBahsRedBlackTreeLibrary.isNotEmpty(bestMatchingPrice) &&
               ((info.buySell == BuySell.Buy && Price.unwrap(bestMatchingPrice) <= Price.unwrap(info.price)) ||
                (info.buySell == BuySell.Sell && Price.unwrap(bestMatchingPrice) >= Price.unwrap(info.price))) &&
               uint128(Delta.unwrap(info.tokens)) > 0) {
            OrderQueue storage orderQueue = orderQueues[moreInfo.pairKey][moreInfo.inverseBuySell][bestMatchingPrice];
            OrderKey bestMatchingOrderKey = orderQueue.head;
            while (isNotSentinel(bestMatchingOrderKey)) {
                Order storage order = orders[bestMatchingOrderKey];
                bool deleteOrder = false;
                if (Unixtime.unwrap(order.expiry) == 0 || Unixtime.unwrap(order.expiry) >= block.timestamp) {
                    uint makerTokensToFill = Tokens.unwrap(order.tokens) - Tokens.unwrap(order.filled);
                    uint tokensToTransfer;
                    uint quoteTokensToTransfer;
                    if (info.buySell == BuySell.Buy) {
                        uint _availableTokens = availableTokens(pair.base, order.maker);
                        if (_availableTokens > 0) {
                            if (makerTokensToFill > _availableTokens) {
                                makerTokensToFill = _availableTokens;
                            }
                            if (uint128(Delta.unwrap(info.tokens)) >= makerTokensToFill) {
                                tokensToTransfer = makerTokensToFill;
                                deleteOrder = true;
                            } else {
                                tokensToTransfer = uint(uint128(Delta.unwrap(info.tokens)));
                            }
                            quoteTokensToTransfer = (10 ** Factor.unwrap(pair.divisor)) * tokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / (10 ** Factor.unwrap(pair.multiplier));
                            if (Account.unwrap(order.maker) != msg.sender) {
                                transferFrom(pair.quote, Account.wrap(msg.sender), order.maker, quoteTokensToTransfer);
                                transferFrom(pair.base, order.maker, Account.wrap(msg.sender), tokensToTransfer);
                            }
                            emit Trade(moreInfo.pairKey, bestMatchingOrderKey, info.buySell, moreInfo.taker, order.maker, tokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
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
                            if (uint128(Delta.unwrap(info.tokens)) >= makerTokensToFill) {
                                tokensToTransfer = makerTokensToFill;
                                quoteTokensToTransfer = availableQuoteTokens;
                                deleteOrder = true;
                            } else {
                                tokensToTransfer = uint(uint128(Delta.unwrap(info.tokens)));
                                quoteTokensToTransfer = (10 ** Factor.unwrap(pair.divisor)) * tokensToTransfer * uint(Price.unwrap(bestMatchingPrice)) / (10 ** Factor.unwrap(pair.multiplier));
                            }
                            if (Account.unwrap(order.maker) != msg.sender) {
                                transferFrom(pair.base, Account.wrap(msg.sender), order.maker, tokensToTransfer);
                                transferFrom(pair.quote, order.maker, Account.wrap(msg.sender), quoteTokensToTransfer);
                            }
                            emit Trade(moreInfo.pairKey, bestMatchingOrderKey, info.buySell, moreInfo.taker, order.maker, tokensToTransfer, quoteTokensToTransfer, bestMatchingPrice);
                        } else {
                            deleteOrder = true;
                        }
                    }
                    order.filled = Tokens.wrap(Tokens.unwrap(order.filled) + uint128(tokensToTransfer));
                    filled = Tokens.wrap(Tokens.unwrap(filled) + uint128(tokensToTransfer));
                    quoteTokensFilled = Tokens.wrap(Tokens.unwrap(quoteTokensFilled) + uint128(quoteTokensToTransfer));
                    info.tokens = Delta.wrap(int128(uint128(Delta.unwrap(info.tokens)) - uint128(tokensToTransfer)));
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
                if (Delta.unwrap(info.tokens) == 0) {
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
        if (info.action == Action.FillAllOrNothing) {
            if (Delta.unwrap(info.tokens) > 0) {
                revert UnableToFillOrder(Tokens.wrap(uint128(Delta.unwrap(info.tokens))));
            }
        }
        if (Delta.unwrap(info.tokens) > 0 && (info.action == Action.FillAnyAndAddOrder)) {
            // TODO require(moreInfo.expiry > block.timestamp);
            orderKey = _addOrder(info, moreInfo);
            tokensOnOrder = Tokens.wrap(uint128(Delta.unwrap(info.tokens)));
        }
        if (Tokens.unwrap(filled) > 0 || Tokens.unwrap(quoteTokensFilled) > 0) {
            uint256 price = Tokens.unwrap(filled) > 0 ? (10 ** Factor.unwrap(pair.multiplier)) * uint(Tokens.unwrap(quoteTokensFilled)) / uint(Tokens.unwrap(filled)) / (10 ** Factor.unwrap(pair.divisor)) : 0;
            emit TradeSummary(info.buySell, moreInfo.taker, filled, quoteTokensFilled, Price.wrap(uint64(price)), tokensOnOrder);
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
}