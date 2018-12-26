pragma solidity ^0.5.0;

// ----------------------------------------------------------------------------
// BokkyPooBah's Decentralised Exchange
//
// https://github.com/bokkypoobah/Dexz
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018.
//
// ----------------------------------------------------------------------------



// ----------------------------------------------------------------------------
// BokkyPooBah's Red-Black Tree Library v0.90
//
// A Solidity Red-Black Tree library to store and access a sorted list of
// unsigned integer data in a binary search tree.
// The Red-Black algorithm rebalances the binary search tree, resulting in
// O(log n) insert, remove and search time (and ~gas)
//
// https://github.com/bokkypoobah/BokkyPooBahsRedBlackTreeLibrary
//
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018. The MIT Licence.
// ----------------------------------------------------------------------------
library BokkyPooBahsRedBlackTreeLibrary {
    struct Node {
        uint parent;
        uint left;
        uint right;
        bool red;
    }

    struct Tree {
        uint root;
        mapping(uint => Node) nodes;
        bool initialised;
        uint inserted;
        uint removed;
    }

    uint private constant SENTINEL = 0;

    event Log(string where, string action, uint key, uint parent, uint left, uint right, bool red);

    function init(Tree storage self) internal {
        require(!self.initialised);
        self.root = SENTINEL;
        self.nodes[SENTINEL] = Node(SENTINEL, SENTINEL, SENTINEL, false);
        self.initialised = true;
    }
    function count(Tree storage self) internal view returns (uint _count) {
        return self.inserted >= self.removed ? self.inserted - self.removed: 0;
    }
    function first(Tree storage self) internal view returns (uint _key) {
        _key = self.root;
        while (_key != SENTINEL && self.nodes[_key].left != SENTINEL) {
            _key = self.nodes[_key].left;
        }
    }
    function last(Tree storage self) internal view returns (uint _key) {
        _key = self.root;
        while (_key != SENTINEL && self.nodes[_key].right != SENTINEL) {
            _key = self.nodes[_key].right;
        }
    }
    function next(Tree storage self, uint x) internal view returns (uint y) {
        require(x != SENTINEL);
        if (self.nodes[x].right != SENTINEL) {
            y = treeMinimum(self, self.nodes[x].right);
        } else {
            y = self.nodes[x].parent;
            while (y != SENTINEL && x == self.nodes[y].right) {
                x = y;
                y = self.nodes[y].parent;
            }
        }
        return y;
    }
    function prev(Tree storage self, uint x) internal view returns (uint y) {
        require(x != SENTINEL);
        if (self.nodes[x].left != SENTINEL) {
            y = treeMaximum(self, self.nodes[x].left);
        } else {
            y = self.nodes[x].parent;
            while (y != SENTINEL && x == self.nodes[y].left) {
                x = y;
                y = self.nodes[y].parent;
            }
        }
        return y;
    }
    function exists(Tree storage self, uint key) internal view returns (bool) {
        require(key != SENTINEL);
        uint _key = self.root;
        while (_key != SENTINEL) {
            if (key == _key) {
                return true;
            }
            if (key < _key) {
                _key = self.nodes[_key].left;
            } else {
                _key = self.nodes[_key].right;
            }
        }
        return false;
    }
    function isSentinel(uint key) internal pure returns (bool) {
        return key == SENTINEL;
    }
    function getNode(Tree storage self, uint key) internal view returns (uint _returnKey, uint _parent, uint _left, uint _right, bool _red) {
        require(key != SENTINEL);
        uint _key = self.root;
        while (_key != SENTINEL) {
            if (key == _key) {
                Node memory node = self.nodes[key];
                return (key, node.parent, node.left, node.right, node.red);
            }
            if (key < _key) {
                _key = self.nodes[_key].left;
            } else {
                _key = self.nodes[_key].right;
            }
        }
        return (SENTINEL, SENTINEL, SENTINEL, SENTINEL, false);
    }
    function parent(Tree storage self, uint key) internal view returns (uint _parent) {
        require(key != SENTINEL);
        _parent = self.nodes[key].parent;
    }
    function grandparent(Tree storage self, uint key) internal view returns (uint _grandparent) {
        require(key != SENTINEL);
        uint _parent = self.nodes[key].parent;
        if (_parent != SENTINEL) {
            _grandparent = self.nodes[_parent].parent;
        } else {
            _grandparent = SENTINEL;
        }
    }
    function sibling(Tree storage self, uint key) internal view returns (uint _sibling) {
        require(key != SENTINEL);
        uint _parent = self.nodes[key].parent;
        if (_parent != SENTINEL) {
            if (key == self.nodes[_parent].left) {
                _sibling = self.nodes[_parent].right;
            } else {
                _sibling = self.nodes[_parent].left;
            }
        } else {
            _sibling = SENTINEL;
        }
    }
    function uncle(Tree storage self, uint key) internal view returns (uint _uncle) {
        require(key != SENTINEL);
        uint _grandParent = grandparent(self, key);
        if (_grandParent != SENTINEL) {
            uint _parent = self.nodes[key].parent;
            _uncle = sibling(self, _parent);
        } else {
            _uncle = SENTINEL;
        }
    }

    function insert(Tree storage self, uint z) public {
        require(z != SENTINEL);
        bool duplicateFound = false;
        uint y = SENTINEL;
        uint x = self.root;
        while (x != SENTINEL) {
            y = x;
            if (z < x) {
                x = self.nodes[x].left;
            } else {
                if (z == x) {
                    duplicateFound = true;
                    break;
                }
                x = self.nodes[x].right;
            }
        }
        require(!duplicateFound);
        self.nodes[z] = Node(y, SENTINEL, SENTINEL, true);
        if (y == SENTINEL) {
            self.root = z;
        } else if (z < y) {
            self.nodes[y].left = z;
        } else {
            self.nodes[y].right = z;
        }
        insertFixup(self, z);
        self.inserted++;
    }
    function remove(Tree storage self, uint z) public {
        require(z != SENTINEL);
        uint x;
        uint y;

        // z can be root OR z is not root && parent cannot be the SENTINEL
        require(z == self.root || (z != self.root && self.nodes[z].parent != SENTINEL));

        if (self.nodes[z].left == SENTINEL || self.nodes[z].right == SENTINEL) {
            y = z;
        } else {
            y = self.nodes[z].right;
            while (self.nodes[y].left != SENTINEL) {
                y = self.nodes[y].left;
            }
        }
        if (self.nodes[y].left != SENTINEL) {
            x = self.nodes[y].left;
        } else {
            x = self.nodes[y].right;
        }
        uint yParent = self.nodes[y].parent;
        self.nodes[x].parent = yParent;
        if (yParent != SENTINEL) {
            if (y == self.nodes[yParent].left) {
                self.nodes[yParent].left = x;
            } else {
                self.nodes[yParent].right = x;
            }
        } else {
            self.root = x;
        }
        bool doFixup = !self.nodes[y].red;
        if (y != z) {
            replaceParent(self, y, z);
            self.nodes[y].left = self.nodes[z].left;
            self.nodes[self.nodes[y].left].parent = y;
            self.nodes[y].right = self.nodes[z].right;
            self.nodes[self.nodes[y].right].parent = y;
            self.nodes[y].red = self.nodes[z].red;
            (y, z) = (z, y);
        }
        if (doFixup) {
            removeFixup(self, x);
        }
        // Below `delete self.nodes[SENTINEL]` may not be necessary
        // TODO - Remove after testing
        // emit Log("remove", "before delete self.nodes[0]", 0, self.nodes[0].parent, self.nodes[0].left, self.nodes[0].right, self.nodes[0].red);
        // emit Log("remove", "before delete self.nodes[SENTINEL]", SENTINEL, self.nodes[SENTINEL].parent, self.nodes[SENTINEL].left, self.nodes[SENTINEL].right, self.nodes[SENTINEL].red);
        if (self.nodes[SENTINEL].parent != SENTINEL) {
            delete self.nodes[SENTINEL];
        }
        delete self.nodes[y];
        self.removed++;
    }

    function treeMinimum(Tree storage self, uint key) private view returns (uint) {
        while (self.nodes[key].left != SENTINEL) {
            key = self.nodes[key].left;
        }
        return key;
    }
    function treeMaximum(Tree storage self, uint key) private view returns (uint) {
        while (self.nodes[key].right != SENTINEL) {
            key = self.nodes[key].right;
        }
        return key;
    }

    function rotateLeft(Tree storage self, uint x) private {
        uint y = self.nodes[x].right;
        uint _parent = self.nodes[x].parent;
        uint yLeft = self.nodes[y].left;
        self.nodes[x].right = yLeft;
        if (yLeft != SENTINEL) {
            self.nodes[yLeft].parent = x;
        }
        self.nodes[y].parent = _parent;
        if (_parent == SENTINEL) {
            self.root = y;
        } else if (x == self.nodes[_parent].left) {
            self.nodes[_parent].left = y;
        } else {
            self.nodes[_parent].right = y;
        }
        self.nodes[y].left = x;
        self.nodes[x].parent = y;
    }
    function rotateRight(Tree storage self, uint x) private {
        uint y = self.nodes[x].left;
        uint _parent = self.nodes[x].parent;
        uint yRight = self.nodes[y].right;
        self.nodes[x].left = yRight;
        if (yRight != SENTINEL) {
            self.nodes[yRight].parent = x;
        }
        self.nodes[y].parent = _parent;
        if (_parent == SENTINEL) {
            self.root = y;
        } else if (x == self.nodes[_parent].right) {
            self.nodes[_parent].right = y;
        } else {
            self.nodes[_parent].left = y;
        }
        self.nodes[y].right = x;
        self.nodes[x].parent = y;
    }

    function insertFixup(Tree storage self, uint z) private {
        uint y;

        while (z != self.root && self.nodes[self.nodes[z].parent].red) {
            uint zParent = self.nodes[z].parent;
            if (zParent == self.nodes[self.nodes[zParent].parent].left) {
                y = self.nodes[self.nodes[zParent].parent].right;
                if (self.nodes[y].red) {
                    self.nodes[zParent].red = false;
                    self.nodes[y].red = false;
                    self.nodes[self.nodes[zParent].parent].red = true;
                    z = self.nodes[zParent].parent;
                } else {
                    if (z == self.nodes[zParent].right) {
                      z = zParent;
                      rotateLeft(self, z);
                    }
                    zParent = self.nodes[z].parent;
                    self.nodes[zParent].red = false;
                    self.nodes[self.nodes[zParent].parent].red = true;
                    rotateRight(self, self.nodes[zParent].parent);
                }
            } else {
                y = self.nodes[self.nodes[zParent].parent].left;
                if (self.nodes[y].red) {
                    self.nodes[zParent].red = false;
                    self.nodes[y].red = false;
                    self.nodes[self.nodes[zParent].parent].red = true;
                    z = self.nodes[zParent].parent;
                } else {
                    if (z == self.nodes[zParent].left) {
                      z = zParent;
                      rotateRight(self, z);
                    }
                    zParent = self.nodes[z].parent;
                    self.nodes[zParent].red = false;
                    self.nodes[self.nodes[zParent].parent].red = true;
                    rotateLeft(self, self.nodes[zParent].parent);
                }
            }
        }
        self.nodes[self.root].red = false;
    }

    function replaceParent(Tree storage self, uint a, uint b) private {
        uint bParent = self.nodes[b].parent;
        self.nodes[a].parent = bParent;
        if (bParent == SENTINEL) {
            self.root = a;
        } else {
            if (b == self.nodes[bParent].left) {
                self.nodes[bParent].left = a;
            } else {
                self.nodes[bParent].right = a;
            }
        }
    }
    function removeFixup(Tree storage self, uint x) private {
        uint w;
        while (x != self.root && !self.nodes[x].red) {
            uint xParent = self.nodes[x].parent;
            if (x == self.nodes[xParent].left) {
                w = self.nodes[xParent].right;
                if (self.nodes[w].red) {
                    self.nodes[w].red = false;
                    self.nodes[xParent].red = true;
                    rotateLeft(self, xParent);
                    w = self.nodes[xParent].right;
                }
                if (!self.nodes[self.nodes[w].left].red && !self.nodes[self.nodes[w].right].red) {
                    self.nodes[w].red = true;
                    x = xParent;
                } else {
                    if (!self.nodes[self.nodes[w].right].red) {
                        self.nodes[self.nodes[w].left].red = false;
                        self.nodes[w].red = true;
                        rotateRight(self, w);
                        w = self.nodes[xParent].right;
                    }
                    self.nodes[w].red = self.nodes[xParent].red;
                    self.nodes[xParent].red = false;
                    self.nodes[self.nodes[w].right].red = false;
                    rotateLeft(self, xParent);
                    x = self.root;
                }
            } else {
                w = self.nodes[xParent].left;
                if (self.nodes[w].red) {
                    self.nodes[w].red = false;
                    self.nodes[xParent].red = true;
                    rotateRight(self, xParent);
                    w = self.nodes[xParent].left;
                }
                if (!self.nodes[self.nodes[w].right].red && !self.nodes[self.nodes[w].left].red) {
                    self.nodes[w].red = true;
                    x = xParent;
                } else {
                    if (!self.nodes[self.nodes[w].left].red) {
                        self.nodes[self.nodes[w].right].red = false;
                        self.nodes[w].red = true;
                        rotateLeft(self, w);
                        w = self.nodes[xParent].left;
                    }
                    self.nodes[w].red = self.nodes[xParent].red;
                    self.nodes[xParent].red = false;
                    self.nodes[self.nodes[w].left].red = false;
                    rotateRight(self, xParent);
                    x = self.root;
                }
            }
        }
        self.nodes[x].red = false;
    }
}
// ----------------------------------------------------------------------------
// End - BokkyPooBah's Red-Black Tree Library
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
    function max(uint a, uint b) internal pure returns (uint c) {
        c = a >= b ? a : b;
    }
    function min(uint a, uint b) internal pure returns (uint c) {
        c = a <= b ? a : b;
    }
}
// ----------------------------------------------------------------------------
// End - Safe maths
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}
// ----------------------------------------------------------------------------
// End - ERC Token Standard #20 Interface
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function initOwned(address _owner) internal {
        owner = _owner;
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
// ----------------------------------------------------------------------------
// End - Owned contract
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase is Owned {
    using SafeMath for uint;

    enum TokenWhitelistStatus {
        NONE,
        BLACKLIST,
        WHITELIST
    }

    uint constant public TENPOW18 = uint(10)**18;

    uint public deploymentBlockNumber;
    uint public takerFee = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    mapping(address => TokenWhitelistStatus) public tokenWhitelist;

    // Data => block.number when first seen
    mapping(address => uint) tokens;
    mapping(address => uint) accounts;
    mapping(bytes32 => uint) pairs;

    event TokenWhitelistUpdated(address indexed token, uint oldStatus, uint newStatus);
    event TakerFeeUpdated(uint oldTakerFee, uint newTakerFee);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);

    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);


    constructor(address _feeAccount) public {
        initOwned(msg.sender);
        deploymentBlockNumber = block.number;
        feeAccount = _feeAccount;
        addAccount(address(this));
    }

    function getTokenBlockNumber(address token) public view returns (uint _blockNumber) {
        _blockNumber = tokens[token];
    }
    function getAccountBlockNumber(address account) public view returns (uint _blockNumber) {
        _blockNumber = accounts[account];
    }
    function getPairBlockNumber(bytes32 _pairKey) public view returns (uint _blockNumber) {
        _blockNumber = pairs[_pairKey];
    }


    function whitelistToken(address token, uint status) public onlyOwner {
        emit TokenWhitelistUpdated(token, uint(tokenWhitelist[token]), status);
        tokenWhitelist[token] = TokenWhitelistStatus(status);
    }
    function setTakerFee(uint _takerFee) public onlyOwner {
        emit TakerFeeUpdated(takerFee, _takerFee);
        takerFee = _takerFee;
    }
    function setFeeAccount(address _feeAccount) public onlyOwner {
        emit FeeAccountUpdated(feeAccount, _feeAccount);
        feeAccount = _feeAccount;
    }

    function addToken(address token) internal {
        if (tokens[token] == 0) {
            tokens[token] = block.number;
            emit TokenAdded(token);
        }
    }
    function addAccount(address account) internal {
        if (accounts[account] == 0) {
            accounts[account] = block.number;
            emit AccountAdded(account);
        }
    }
    function addPair(bytes32 _pairKey, address baseToken, address quoteToken) internal {
        if (pairs[_pairKey] == 0) {
            pairs[_pairKey] = block.number;
            emit PairAdded(_pairKey, baseToken, quoteToken);
        }
    }


    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        _tokens = ERC20Interface(token).allowance(wallet, address(this));
        _tokens = _tokens.min(ERC20Interface(token).balanceOf(wallet));
    }
    function transferFrom(address token, address from, address to, uint _tokens) internal {
        TokenWhitelistStatus whitelistStatus = tokenWhitelist[token];
        // Difference in gas for 2 x maker fills - wl 293405, no wl 326,112
        if (whitelistStatus == TokenWhitelistStatus.WHITELIST) {
            require(ERC20Interface(token).transferFrom(from, to, _tokens));
        } else if (whitelistStatus == TokenWhitelistStatus.NONE) {
            uint balanceToBefore = ERC20Interface(token).balanceOf(to);
            require(ERC20Interface(token).transferFrom(from, to, _tokens));
            uint balanceToAfter = ERC20Interface(token).balanceOf(to);
            require(balanceToBefore.add(_tokens) == balanceToAfter);
        } else {
            revert();
        }
    }
}
// ----------------------------------------------------------------------------
// End - DexzBase
// ----------------------------------------------------------------------------

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


// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is Orders {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    event Trade(bytes32 indexed key, uint orderType, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);

    constructor(address _feeAccount) public Orders(_feeAccount) {
    }

    function addOrder(OrderType orderType, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, */ uint _baseTokensOnOrder, bytes32 _orderKey) {
        // BK TODO - Add check for expiry
        _baseTokensOnOrder = baseTokens;

        bytes32 matchingOrderKey = _getBestMatchingOrder(orderType, baseToken, quoteToken, price);
        emit LogInfo("addOrder: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        while (matchingOrderKey != ORDERKEY_SENTINEL && _baseTokensOnOrder > 0) {
            uint _baseTokens;
            uint _quoteTokens;
            Orders.Order storage order = orders[matchingOrderKey];
            emit LogInfo("addOrder: order", order.baseTokens, matchingOrderKey, "", order.maker);
            (_baseTokens, _quoteTokens) = calculateOrder(matchingOrderKey, _baseTokensOnOrder, msg.sender);
            emit LogInfo("addOrder: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            emit LogInfo("addOrder: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            if (_baseTokens > 0 && _quoteTokens > 0) {
                order.baseTokensFilled = order.baseTokensFilled.add(_baseTokens);
                uint takerFeeTokens;

                if (orderType == OrderType.SELL) {
                    emit LogInfo("addOrder: order SELL", 0, 0x0, "", address(0));

                    takerFeeTokens = _quoteTokens.mul(takerFee).div(TENPOW18);
                    // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens, _quoteTokens.sub(takerFeeTokens), 0, takerFeeTokens, order.baseTokensFilled);

                    transferFrom(order.baseToken, msg.sender, order.maker, _baseTokens);
                    transferFrom(order.quoteToken, order.maker, msg.sender, _quoteTokens.sub(takerFeeTokens));
                    if (takerFeeTokens > 0) {
                        transferFrom(order.quoteToken, order.maker, uiFeeAccount, takerFeeTokens/2);
                        transferFrom(order.quoteToken, order.maker, feeAccount, takerFeeTokens - takerFeeTokens/2);
                    }

                } else {
                    emit LogInfo("addOrder: order BUY", 0, 0x0, "", address(0));

                    takerFeeTokens = _baseTokens.mul(takerFee).div(TENPOW18);
                    // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, order.baseTokensFilled);

                    transferFrom(order.quoteToken, msg.sender, order.maker, _quoteTokens);
                    transferFrom(order.baseToken, order.maker, msg.sender, _baseTokens.sub(takerFeeTokens));
                    if (takerFeeTokens > 0) {
                        transferFrom(order.baseToken, order.maker, uiFeeAccount, takerFeeTokens/2);
                        transferFrom(order.baseToken, order.maker, feeAccount, takerFeeTokens - takerFeeTokens/2);
                    }
                }
                _baseTokensOnOrder = _baseTokensOnOrder.sub(_baseTokens);
                // _baseTokensFilled = _baseTokensFilled.add(_baseTokens);
                // _quoteTokensFilled = _quoteTokensFilled.add(_quoteTokens);
                _updateBestMatchingOrder(orderType, baseToken, quoteToken, price, matchingOrderKey);
                // matchingOrderKey = ORDERKEY_SENTINEL;
                matchingOrderKey = _getBestMatchingOrder(orderType, baseToken, quoteToken, price);
            }
        }
        if (_baseTokensOnOrder > 0) {
            require(expiry > now);
            _orderKey = _addOrder(orderType, msg.sender, baseToken, quoteToken, price, expiry, _baseTokensOnOrder);
        }
    }

    function calculateOrder(bytes32 _matchingOrderKey, uint amountBaseTokens, address taker) internal returns (uint baseTokens, uint quoteTokens) {
        Orders.Order storage matchingOrder = orders[_matchingOrderKey];
        require(now <= matchingOrder.expiry);

        // // Maker buying base, needs to have amount in quote = base x price
        // // Taker selling base, needs to have amount in base
        if (matchingOrder.orderType == OrderType.BUY) {
            emit LogInfo("calculateOrder Buy: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Buy: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Buy: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, taker);
            emit LogInfo("calculateOrder Buy: availableTokens(matchingOrder.baseToken, taker)", _availableBaseTokens, 0x0, "", taker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Buy: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Buy: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            baseTokens = baseTokens.min(_availableBaseTokens);
            emit LogInfo("calculateOrder Buy: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, taker))", baseTokens, 0x0, "", taker);

            emit LogInfo("calculateOrder Buy: quoteTokens = baseTokens x price / 1e18", baseTokens.mul(matchingOrder.price).div(TENPOW18), 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Buy: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", matchingOrder.maker);
            if (matchingOrder.orderType == OrderType.BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            quoteTokens = quoteTokens.min(_availableQuoteTokens);
            emit LogInfo("calculateOrder Buy: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, matchingOrder.maker))", quoteTokens, 0x0, "", matchingOrder.maker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            baseTokens = baseTokens.min(quoteTokens.mul(TENPOW18).div(matchingOrder.price));
            emit LogInfo("calculateOrder Buy: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            emit LogInfo("calculateOrder Buy: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));

        // Maker selling base, needs to have amount in base
        // Taker buying base, needs to have amount in quote = base x price
        } else if (matchingOrder.orderType == OrderType.SELL) {
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Sell: availableTokens(matchingOrder.baseToken, matchingOrder.maker)", _availableBaseTokens, 0x0, "", matchingOrder.maker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.orderType == OrderType.SELL && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Sell: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Sell: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            baseTokens = baseTokens.min(_availableBaseTokens);
            emit LogInfo("calculateOrder Sell: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, matchingOrder.maker))", baseTokens, 0x0, "", matchingOrder.maker);

            emit LogInfo("calculateOrder Sell: quoteTokens = baseTokens x price / 1e18", baseTokens.mul(matchingOrder.price).div(TENPOW18), 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, taker);
            emit LogInfo("calculateOrder Sell: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", taker);
            if (matchingOrder.orderType == OrderType.BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            quoteTokens = quoteTokens.min(_availableQuoteTokens);
            emit LogInfo("calculateOrder Sell: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, taker))", quoteTokens, 0x0, "", taker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            baseTokens = baseTokens.min(quoteTokens.mul(TENPOW18).div(matchingOrder.price));
            emit LogInfo("calculateOrder Sell: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            emit LogInfo("calculateOrder Sell: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));
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
        bytes32 oldKey = Orders.orderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, oldPrice, expiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.orderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, newPrice, expiry);
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
        bytes32 oldKey = Orders.orderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, oldExpiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.orderKey(OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, newExpiry);
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
    */
    function removeOrder(bytes32 key) public {
        _removeOrder(key, msg.sender);
    }
}
