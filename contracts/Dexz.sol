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


interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
}


contract Owned {
    address public owner;
    address public newOwner;
    bool private initialised;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function initOwned(address _owner) internal {
        require(!initialised);
        owner = _owner;
        initialised = true;
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
// DexzBase
// ----------------------------------------------------------------------------
contract DexzBase is Owned {
    uint constant public TENPOW18 = uint(10)**18;

    uint public deploymentBlockNumber;
    uint public takerFeeInEthers = 5 * 10 ** 16; // 0.05 ETH
    uint public takerFeeInTokens = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    struct PairInfo {
        bytes32 pairKey;
        address baseToken;
        address quoteToken;
    }

    // Data => block.number when first seen
    mapping(address => uint) public tokenBlockNumbers;
    mapping(address => uint) public accountBlockNumbers;
    mapping(bytes32 => uint) public pairBlockNumbers;
    address[] public tokenList;
    address[] public accountList;
    PairInfo[] public pairInfoList;

    event TakerFeeInEthersUpdated(uint oldTakerFeeInEthers, uint newTakerFeeInEthers);
    event TakerFeeInTokensUpdated(uint oldTakerFeeInTokens, uint newTakerFeeInTokens);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);

    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);


    constructor(address _feeAccount) {
        initOwned(msg.sender);
        deploymentBlockNumber = block.number;
        feeAccount = _feeAccount;
        addAccount(address(this));
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

    function tokenListLength() public view returns (uint) {
        return tokenList.length;
    }
    function addToken(address token) internal {
        if (tokenBlockNumbers[token] == 0) {
            require(IERC20(token).totalSupply() > 0);
            tokenBlockNumbers[token] = block.number;
            tokenList.push(token);
            emit TokenAdded(token);
        }
    }
    function accountListLength() public view returns (uint) {
        return accountList.length;
    }
    function addAccount(address account) internal {
        if (accountBlockNumbers[account] == 0) {
            accountBlockNumbers[account] = block.number;
            accountList.push(account);
            emit AccountAdded(account);
        }
    }
    function pairInfoListLength() public view returns (uint) {
        return pairInfoList.length;
    }
    function addPair(bytes32 _pairKey, address baseToken, address quoteToken) internal {
        if (pairBlockNumbers[_pairKey] == 0) {
            pairBlockNumbers[_pairKey] = block.number;
            pairInfoList.push(PairInfo(_pairKey, baseToken, quoteToken));
            emit PairAdded(_pairKey, baseToken, quoteToken);
        }
    }


    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        uint _allowance = IERC20(token).allowance(wallet, address(this));
        uint _balance = IERC20(token).balanceOf(wallet);
        if (_allowance < _balance) {
            return _allowance;
        } else {
            return _balance;
        }
    }
    function transferFrom(address token, address from, address to, uint _tokens) internal {
        // TODO: Remove check?
        uint balanceToBefore = IERC20(token).balanceOf(to);
        require(IERC20(token).transferFrom(from, to, _tokens));
        uint balanceToAfter = IERC20(token).balanceOf(to);
        require(balanceToBefore + _tokens == balanceToAfter);
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
    uint constant public ORDERTYPE_BUY = 0x00;
    uint constant public ORDERTYPE_SELL = 0x01;
    uint constant public ORDERFLAG_BUYSELL_MASK = 0x01;
    // BK Default is to fill as much as possible
    uint constant public ORDERFLAG_FILL = 0x00;
    uint constant public ORDERFLAG_FILLALL_OR_REVERT = 0x10;
    uint constant public ORDERFLAG_FILL_AND_ADD_ORDER = 0x20;

    // 0.00054087 = new BigNumber(54087).shift(10);
    // GNT/ETH = base/quote = 0.00054087
    struct Order {
        bytes32 prev;
        bytes32 next;
        uint orderType;
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

    // PairKey (bytes32) => BuySell (uint) => Price (BPBRBTL)
    mapping(bytes32 => mapping(uint => BokkyPooBahsRedBlackTreeLibrary.Tree)) orderKeys;
    // PairKey (bytes32) => BuySell (uint) => Price (uint) => OrderQueue
    mapping(bytes32 => mapping(uint => mapping(uint => OrderQueue))) orderQueue;
    // OrderKey (bytes32) => Order
    mapping(bytes32 => Order) orders;

    bytes32 public constant ORDERKEY_SENTINEL = 0x0;

    event OrderAdded(bytes32 indexed pairKey, bytes32 indexed key, uint orderType, address indexed maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens);
    event OrderRemoved(bytes32 indexed key);
    event OrderUpdated(bytes32 indexed key, uint baseTokens, uint newBaseTokens);


    constructor(address _feeAccount) DexzBase(_feeAccount) {
    }


    // Price tree navigating
    // BK TODO function count(bytes32 _pairKey, uint _orderType) public view returns (uint _count) {
    // BK TODO     _count = orderKeys[_pairKey][_orderType].count();
    // BK TODO }
    function first(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][_orderType].first();
    }
    function last(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = orderKeys[_pairKey][_orderType].last();
    }
    function next(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        _y = orderKeys[_pairKey][_orderType].next(_x);
    }
    function prev(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        _y = orderKeys[_pairKey][_orderType].prev(_x);
    }
    function exists(bytes32 _pairKey, uint _orderType, uint _key) public view returns (bool) {
        return orderKeys[_pairKey][_orderType].exists(_key);
    }
    function getNode(bytes32 _pairKey, uint _orderType, uint _key) public view returns (uint _returnKey, uint _parent, uint _left, uint _right, bool _red) {
        return orderKeys[_pairKey][_orderType].getNode(_key);
    }
    // Don't need parent, grandparent, sibling, uncle


    // Orders navigating
    function pairKey(address _baseToken, address _quoteToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_baseToken, _quoteToken));
    }
    function orderKey(uint _orderType, address _maker, address _baseToken, address _quoteToken, uint _price, uint _expiry) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_orderType, _maker, _baseToken, _quoteToken, _price, _expiry));
    }
    function exists(bytes32 _key) internal view returns (bool) {
        return orders[_key].baseToken != address(0);
    }
    function inverseOrderType(uint _orderType) internal pure returns (uint) {
        return (_orderType == ORDERTYPE_BUY) ? ORDERTYPE_SELL : ORDERTYPE_BUY;
    }


    function getBestPrice(bytes32 _pairKey, uint _orderType) public view returns (uint _key) {
        _key = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].first() : orderKeys[_pairKey][_orderType].last();
    }
    function getNextBestPrice(bytes32 _pairKey, uint _orderType, uint _x) public view returns (uint _y) {
        if (BokkyPooBahsRedBlackTreeLibrary.isEmpty(_x)) {
            _y = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].first() : orderKeys[_pairKey][_orderType].last();
        } else {
            _y = (_orderType == ORDERTYPE_BUY) ? orderKeys[_pairKey][_orderType].next(_x) : orderKeys[_pairKey][_orderType].prev(_x);
        }
    }

    function getOrderQueue(bytes32 _pairKey, uint _orderType, uint _price) public view returns (bool _exists, bytes32 _head, bytes32 _tail) {
        Orders.OrderQueue memory _orderQueue = orderQueue[_pairKey][_orderType][_price];
        return (_orderQueue.exists, _orderQueue.head, _orderQueue.tail);
    }
    function getOrder(bytes32 _orderKey) public view returns (bytes32 _prev, bytes32 _next, uint _orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, uint baseTokensFilled) {
        Orders.Order memory order = orders[_orderKey];
        return (order.prev, order.next, order.orderType, order.maker, order.baseToken, order.quoteToken, order.price, order.expiry, order.baseTokens, order.baseTokensFilled);
    }


    function _getBestMatchingOrder(uint _orderType, address baseToken, address quoteToken, uint price) internal returns (uint _bestMatchingPriceKey, bytes32 _bestMatchingOrderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        uint _matchingOrderType = inverseOrderType(_orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_matchingOrderType];
        // SKINNY2 if (priceKeys.initialised) {
            emit LogInfo("getBestMatchingOrder: priceKeys.initialised", 0, 0x0, "", address(0));
            _bestMatchingPriceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.first() : priceKeys.last();
            bool priceOk = BokkyPooBahsRedBlackTreeLibrary.isEmpty(_bestMatchingPriceKey) ? false : (_orderType == ORDERTYPE_BUY) ? _bestMatchingPriceKey <= price : _bestMatchingPriceKey >= price;
            while (priceOk) {
                emit LogInfo("getBestMatchingOrder: _bestMatchingPriceKey", _bestMatchingPriceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][_matchingOrderType][_bestMatchingPriceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("getBestMatchingOrder: orderQueue not empty", _bestMatchingPriceKey, 0x0, "", address(0));
                    _bestMatchingOrderKey = _orderQueue.head;
                    while (_bestMatchingOrderKey != ORDERKEY_SENTINEL) {
                        Order storage order = orders[_bestMatchingOrderKey];
                        emit LogInfo("getBestMatchingOrder: _bestMatchingOrderKey ", order.expiry, _bestMatchingOrderKey, "", address(0));
                        if (order.expiry >= block.timestamp && order.baseTokens > order.baseTokensFilled) {
                            return (_bestMatchingPriceKey, _bestMatchingOrderKey);
                        }
                        _bestMatchingOrderKey = orders[_bestMatchingOrderKey].next;
                    }
                } else {
                    // TODO: REMOVE _bestMatchingPriceKey
                    emit LogInfo("getBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                _bestMatchingPriceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.next(_bestMatchingPriceKey) : priceKeys.prev(_bestMatchingPriceKey);
                priceOk = BokkyPooBahsRedBlackTreeLibrary.isEmpty(_bestMatchingPriceKey) ? false : (_orderType == ORDERTYPE_BUY) ? _bestMatchingPriceKey <= price : _bestMatchingPriceKey >= price;
            // SKINNY2 }
            // OrderQueue storage orderQueue = self.orderQueue[_pairKey][_orderType][price];
        }
        return (BokkyPooBahsRedBlackTreeLibrary.getEmpty(), ORDERKEY_SENTINEL);
    }
    function _updateBestMatchingOrder(uint _orderType, address baseToken, address quoteToken, uint matchingPriceKey, bytes32 matchingOrderKey, bool _orderFilled) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        uint _matchingOrderType = inverseOrderType(_orderType);
        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_matchingOrderType];
        // SKINNY2 if (priceKeys.initialised) {
            emit LogInfo("updateBestMatchingOrder: priceKeys.initialised", 0, 0x0, "", address(0));
            uint priceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.first() : priceKeys.last();
            while (!BokkyPooBahsRedBlackTreeLibrary.isEmpty(priceKey)) {
                emit LogInfo("updateBestMatchingOrder: priceKey", priceKey, 0x0, "", address(0));
                OrderQueue storage _orderQueue = orderQueue[_pairKey][_matchingOrderType][priceKey];
                if (_orderQueue.exists) {
                    emit LogInfo("updateBestMatchingOrder: orderQueue not empty", priceKey, 0x0, "", address(0));

                    Order storage order = orders[matchingOrderKey];
                    // TODO: What happens when allowance or balance is lower than #baseTokens
                    if (_orderFilled) {
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
                    // Clear out queue info, and prie tree if necessary
                    if (_orderQueue.head == ORDERKEY_SENTINEL) {
                        delete orderQueue[_pairKey][_matchingOrderType][priceKey];
                        priceKeys.remove(priceKey);
                        emit LogInfo("orders remove RBT", priceKey, 0x0, "", address(0));
                    }
                } else {
                    priceKeys.remove(priceKey);
                    emit LogInfo("updateBestMatchingOrder: orderQueue empty", 0, 0x0, "", address(0));

                }
                priceKey = (_orderType == ORDERTYPE_BUY) ? priceKeys.next(priceKey) : priceKeys.prev(priceKey);
            // SKINNY2 }
        }
        return ORDERKEY_SENTINEL;
    }
    function _addOrder(uint _orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens) internal returns (bytes32 _orderKey) {
        bytes32 _pairKey = pairKey(baseToken, quoteToken);
        _orderKey = orderKey(_orderType, maker, baseToken, quoteToken, price, expiry);
        require(orders[_orderKey].maker == address(0));

        addToken(baseToken);
        addToken(quoteToken);
        addAccount(maker);
        addPair(_pairKey, baseToken, quoteToken);

        BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_orderType];
        // SKINNY2 if (!priceKeys.initialised) {
        // SKINNY2     priceKeys.init();
        // SKINNY2 }
        if (!priceKeys.exists(price)) {
            priceKeys.insert(price);
            emit LogInfo("orders addKey RBT adding ", price, 0x0, "", address(0));
        } else {
            emit LogInfo("orders addKey RBT exists ", price, 0x0, "", address(0));
        }
        // Above - new 148,521, existing 35,723

        OrderQueue storage _orderQueue = orderQueue[_pairKey][_orderType][price];
        if (!_orderQueue.exists) {
            orderQueue[_pairKey][_orderType][price] = OrderQueue(true, ORDERKEY_SENTINEL, ORDERKEY_SENTINEL);
            _orderQueue = orderQueue[_pairKey][_orderType][price];
        }
        // Above - new 179,681, existing 36,234

        if (_orderQueue.tail == ORDERKEY_SENTINEL) {
            _orderQueue.head = _orderKey;
            _orderQueue.tail = _orderKey;
            orders[_orderKey] = Order(ORDERKEY_SENTINEL, ORDERKEY_SENTINEL, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            emit LogInfo("orders addData  first", 0, _orderKey, "", address(0));
        } else {
            orders[_orderQueue.tail].next = _orderKey;
            orders[_orderKey] = Order(_orderQueue.tail, ORDERKEY_SENTINEL, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens, 0);
            _orderQueue.tail = _orderKey;
            emit LogInfo("orders addData !first", 0, _orderKey, "", address(0));
        }
        // Above saving prev and next - new 232,985, existing 84,961
        // Above saving all - new 385,258, existing 241,975

        emit OrderAdded(_pairKey, _orderKey, _orderType, maker, baseToken, quoteToken, price, expiry, baseTokens);
    }
    function _removeOrder(bytes32 _orderKey, address msgSender) internal {
        require(_orderKey != ORDERKEY_SENTINEL);
        Order memory order = orders[_orderKey];
        require(order.maker == msgSender);

        bytes32 _pairKey = pairKey(order.baseToken, order.quoteToken);
        OrderQueue storage _orderQueue = orderQueue[_pairKey][order.orderType][order.price];
        require(_orderQueue.exists);

        uint _orderType = order.orderType;
        uint _price = order.price;

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
            delete orderQueue[_pairKey][_orderType][_price];
            BokkyPooBahsRedBlackTreeLibrary.Tree storage priceKeys = orderKeys[_pairKey][_orderType];
            if (priceKeys.exists(_price)) {
                priceKeys.remove(_price);
                emit LogInfo("orders remove RBT", _price, 0x0, "", address(0));
            }
        }
    }
}

// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is Orders {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    struct TradeInfo {
        address taker;
        uint orderFlag;
        uint orderType;
        address baseToken;
        address quoteToken;
        uint price;
        uint expiry;
        uint baseTokens;
        address uiFeeAccount;
    }

    // web3.sha3("trade(uint256,address,address,uint256,uint256,uint256,address)").substring(0, 10) => "0xcbb924e2"
    bytes4 public constant tradeSig = "\xcb\xb9\x24\xe2";

    event Trade(bytes32 indexed key, uint orderType, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);

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

    function trade(uint orderFlag, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 _orderKey) {
        return _trade(TradeInfo(msg.sender, orderFlag | ORDERFLAG_FILL_AND_ADD_ORDER, orderFlag & ORDERFLAG_BUYSELL_MASK, baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount));
    }
    function _trade(TradeInfo memory tradeInfo) internal returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 _orderKey) {
        uint matchingPriceKey;
        bytes32 matchingOrderKey;
        (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(tradeInfo.orderType, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price);
        emit LogInfo("_trade: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        while (matchingOrderKey != ORDERKEY_SENTINEL && tradeInfo.baseTokens > 0) {
            uint _baseTokens;
            uint _quoteTokens;
            bool _orderFilled;
            Orders.Order storage order = orders[matchingOrderKey];
            emit LogInfo("_trade: order", order.baseTokens, matchingOrderKey, "", order.maker);
            (_baseTokens, _quoteTokens, _orderFilled) = calculateOrder(matchingOrderKey, tradeInfo.baseTokens, tradeInfo.taker);
            emit LogInfo("_trade: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            emit LogInfo("_trade: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            // if (_baseTokens > 0 && _quoteTokens > 0) {
            //     order.baseTokensFilled = order.baseTokensFilled + _baseTokens;
            //     transferTokens(tradeInfo, tradeInfo.orderType, order.maker, _baseTokens, _quoteTokens, matchingOrderKey);
            //     tradeInfo.baseTokens = tradeInfo.baseTokens - _baseTokens;
            //     _baseTokensFilled = _baseTokensFilled + _baseTokens;
            //     _quoteTokensFilled = _quoteTokensFilled + _quoteTokens;
            //     _updateBestMatchingOrder(tradeInfo.orderType, tradeInfo.baseToken, tradeInfo.quoteToken, matchingPriceKey, matchingOrderKey, _orderFilled);
            //     // matchingOrderKey = ORDERKEY_SENTINEL;
            //     (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(tradeInfo.orderType, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price);
            // }
            break;
        }
        if ((tradeInfo.orderFlag & ORDERFLAG_FILLALL_OR_REVERT) == ORDERFLAG_FILLALL_OR_REVERT) {
            require(tradeInfo.baseTokens == 0);
        }
        if (tradeInfo.baseTokens > 0 && ((tradeInfo.orderFlag & ORDERFLAG_FILL_AND_ADD_ORDER) == ORDERFLAG_FILL_AND_ADD_ORDER)) {
            require(tradeInfo.expiry > block.timestamp);
            _orderKey = _addOrder(tradeInfo.orderType, tradeInfo.taker, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price, tradeInfo.expiry, tradeInfo.baseTokens);
            _baseTokensOnOrder = tradeInfo.baseTokens;
        }
    }

    function calculateOrder(bytes32 _matchingOrderKey, uint amountBaseTokens, address taker) internal returns (uint baseTokens, uint quoteTokens, bool _orderFilled) {
        Orders.Order storage matchingOrder = orders[_matchingOrderKey];
        require(block.timestamp <= matchingOrder.expiry);

        // // Maker buying base, needs to have amount in quote = base x price
        // // Taker selling base, needs to have amount in base
        if (matchingOrder.orderType == ORDERTYPE_BUY) {
            emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Buy: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, taker);
            emit LogInfo("calculateOrder Maker Buy: availableTokens(matchingOrder.baseToken, taker)", _availableBaseTokens, 0x0, "", taker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.baseTokens - matchingOrder.baseTokensFilled > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            // baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            // baseTokens = baseTokens.min(_availableBaseTokens);
            baseTokens = matchingOrder.baseTokens - matchingOrder.baseTokensFilled;
            if (amountBaseTokens < baseTokens) {
                baseTokens = amountBaseTokens;
            }
            if (_availableBaseTokens < baseTokens) {
                baseTokens = _availableBaseTokens;
            }
            emit LogInfo("calculateOrder Maker Buy: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, taker))", baseTokens, 0x0, "", taker);

            emit LogInfo("calculateOrder Maker Buy: quoteTokens = baseTokens x price / 1e18", baseTokens * matchingOrder.price / TENPOW18, 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Maker Buy: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", matchingOrder.maker);
            if (matchingOrder.orderType == ORDERTYPE_BUY && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens * matchingOrder.price / TENPOW18;
            if (_availableQuoteTokens < quoteTokens) {
                quoteTokens = _availableQuoteTokens;
            }
            emit LogInfo("calculateOrder Maker Buy: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, matchingOrder.maker))", quoteTokens, 0x0, "", matchingOrder.maker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            if (quoteTokens * TENPOW18 / matchingOrder.price < baseTokens) {
                baseTokens = quoteTokens * TENPOW18 / matchingOrder.price;
            }
            // baseTokens = baseTokens.min(quoteTokens * TENPOW18 / matchingOrder.price));
            emit LogInfo("calculateOrder Maker Buy: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens * matchingOrder.price / TENPOW18;
            emit LogInfo("calculateOrder Maker Buy: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));

        // Maker selling base, needs to have amount in base
        // Taker buying base, needs to have amount in quote = base x price
        } else if (matchingOrder.orderType == ORDERTYPE_SELL) {
            emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Sell: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Maker Sell: availableTokens(matchingOrder.baseToken, matchingOrder.maker)", _availableBaseTokens, 0x0, "", matchingOrder.maker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.orderType == ORDERTYPE_SELL && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            // baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            // baseTokens = baseTokens.min(_availableBaseTokens);
            baseTokens = matchingOrder.baseTokens - matchingOrder.baseTokensFilled;
            if (amountBaseTokens < baseTokens) {
                baseTokens = amountBaseTokens;
            }
            if (_availableBaseTokens < baseTokens) {
                baseTokens = _availableBaseTokens;
            }
            emit LogInfo("calculateOrder Maker Sell: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, matchingOrder.maker))", baseTokens, 0x0, "", matchingOrder.maker);

            emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", baseTokens * matchingOrder.price / TENPOW18, 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, taker);
            emit LogInfo("calculateOrder Maker Sell: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", taker);
            if (matchingOrder.orderType == ORDERTYPE_BUY && (matchingOrder.baseTokens - matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens * matchingOrder.price / TENPOW18;
            if (_availableQuoteTokens < quoteTokens) {
                quoteTokens = _availableQuoteTokens;
            }
            emit LogInfo("calculateOrder Maker Sell: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, taker))", quoteTokens, 0x0, "", taker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            // baseTokens = baseTokens.min(quoteTokens.mul(TENPOW18).div(matchingOrder.price));
            if (quoteTokens * TENPOW18 / matchingOrder.price < baseTokens) {
                baseTokens = quoteTokens * TENPOW18 / matchingOrder.price;
            }

            emit LogInfo("calculateOrder Maker Sell: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens * matchingOrder.price / TENPOW18;
            emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));
        }
        // TODO BK
        _orderFilled = true;
    }


    // function trade(uint orderType, address taker, address maker, address uiFeeAccount, address baseToken, address quoteToken, uint[2] memory tokens) internal {
    function transferTokens(TradeInfo memory tradeInfo, uint orderType, address maker, uint _baseTokens, uint _quoteTokens, bytes32 matchingOrderKey) internal {
        uint _takerFeeInTokens;
        // bool feeInEthers = (msg.value >= takerFeeInEthers);

        // TODO
        uint __orderBaseTokensFilled = 0;

        if (orderType == ORDERTYPE_BUY) {
            emit LogInfo("transferTokens: BUY", 0, 0x0, "", address(0));
            _takerFeeInTokens = _baseTokens * takerFeeInTokens / TENPOW18;
            emit Trade(matchingOrderKey, orderType, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens - _takerFeeInTokens, _quoteTokens, _takerFeeInTokens, 0, __orderBaseTokensFilled);
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
            emit LogInfo("transferTokens: SELL", 0, 0x0, "", address(0));
            _takerFeeInTokens = _quoteTokens * takerFeeInTokens / TENPOW18;
            emit Trade(matchingOrderKey, orderType, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens, _quoteTokens - _takerFeeInTokens, _takerFeeInTokens, 0, __orderBaseTokensFilled);
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
