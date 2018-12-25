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

import "SafeMath.sol";
import "ERC20Interface.sol";
import "Owned.sol";
import "Orders.sol";


// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is Owned {
    using SafeMath for uint;
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;
    using Orders for Orders.Data;

    bytes32 private constant SENTINEL = 0x0;

    enum TokenWhitelistStatus {
        NONE,
        BLACKLIST,
        WHITELIST
    }
    enum OrderType {
        BUY,
        SELL
    }

    struct Order {
        OrderType orderType;
        address maker;
        address baseToken;
        address quoteToken;
        uint price;             // baseToken/quoteToken = #quoteToken per unit baseToken
        uint expiry;
        uint baseTokens;
        uint baseTokensFilled;
    }

    uint constant private TENPOW18 = uint(10)**18;

    uint public deploymentBlockNumber;
    uint public takerFee = 10 * uint(10)**14; // 0.10%
    address public feeAccount;

    mapping(address => TokenWhitelistStatus) public tokenWhitelist;

    Orders.Data public ordersData;

    event TokenWhitelistUpdated(address indexed token, uint oldStatus, uint newStatus);
    event TakerFeeUpdated(uint oldTakerFee, uint newTakerFee);
    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount);
    event TokenAdded(address indexed token);
    event AccountAdded(address indexed account);
    event PairAdded(bytes32 indexed pairKey, address indexed baseToken, address indexed quoteToken);

    event OrderAdded(bytes32 indexed pairKey, bytes32 indexed key, uint orderType, address indexed maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens);
    event OrderRemoved(bytes32 indexed key);
    event OrderUpdated(bytes32 indexed key, uint baseTokens, uint newBaseTokens);

    event LogInfo(string topic, uint number, bytes32 data, string note, address addr);
    event Trade(bytes32 indexed key, uint orderType, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);

    constructor(address _feeAccount) public {
        deploymentBlockNumber = block.number;
        initOwned(msg.sender);
        feeAccount = _feeAccount;
        ordersData.init();
        ordersData.addAccount(address(this));
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

    function getTokenBlockNumber(address token) public view returns (uint _blockNumber) {
        _blockNumber = ordersData.tokens[token];
    }
    function getAccountBlockNumber(address account) public view returns (uint _blockNumber) {
        _blockNumber = ordersData.accounts[account];
    }
    function getPairBlockNumber(bytes32 _pairKey) public view returns (uint _blockNumber) {
        _blockNumber = ordersData.pairs[_pairKey];
    }

    // Price tree navigating
    function count(bytes32 _pairKey, uint orderType) public view returns (uint _count) {
        _count = ordersData.orderKeys[_pairKey][orderType].count();
    }
    function first(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        _key = ordersData.orderKeys[_pairKey][orderType].first();
    }
    function last(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        _key = ordersData.orderKeys[_pairKey][orderType].last();
    }
    function next(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        y = ordersData.orderKeys[_pairKey][orderType].next(x);
    }
    function prev(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        y = ordersData.orderKeys[_pairKey][orderType].prev(x);
    }
    function exists(bytes32 _pairKey, uint orderType, uint key) public view returns (bool) {
        return ordersData.orderKeys[_pairKey][orderType].exists(key);
    }
    function getNode(bytes32 _pairKey, uint orderType, uint key) public view returns (uint _returnKey, uint _parent, uint _left, uint _right, bool _red) {
        return ordersData.orderKeys[_pairKey][orderType].getNode(key);
    }
    // Don't need parent, grandparent, sibling, uncle

    function getBestPrice(bytes32 _pairKey, uint orderType) public view returns (uint _key) {
        if (orderType == uint(Orders.OrderType.BUY)) {
            _key = ordersData.orderKeys[_pairKey][orderType].last();
        } else {
            _key = ordersData.orderKeys[_pairKey][orderType].first();
        }
    }
    function getNextBestPrice(bytes32 _pairKey, uint orderType, uint x) public view returns (uint y) {
        if (orderType == uint(Orders.OrderType.BUY)) {
            if (BokkyPooBahsRedBlackTreeLibrary.isSentinel(x)) {
                y = ordersData.orderKeys[_pairKey][orderType].last();
            } else {
                y = ordersData.orderKeys[_pairKey][orderType].prev(x);
            }
        } else {
            if (BokkyPooBahsRedBlackTreeLibrary.isSentinel(x)) {
                y = ordersData.orderKeys[_pairKey][orderType].first();
            } else {
                y = ordersData.orderKeys[_pairKey][orderType].next(x);
            }
        }
    }

    function getNextOrder(bytes32 _pairKey, uint orderType) public view returns (uint) {
        uint _key;
        if (orderType == uint(Orders.OrderType.BUY)) {
            _key = ordersData.orderKeys[_pairKey][orderType].last();
        } else {
            _key = ordersData.orderKeys[_pairKey][orderType].first();
        }
    }

    function getOrderQueue(bytes32 _pairKey, uint orderType, uint price) public view returns (bool _exists, bytes32 _head, bytes32 _tail) {
        Orders.OrderQueue memory orderQueue = ordersData.orderQueue[_pairKey][uint(orderType)][price];
        return (orderQueue.exists, orderQueue.head, orderQueue.tail);
    }
    function getOrder(bytes32 orderKey) public view returns (bytes32 _prev, bytes32 _next, uint orderType, address maker, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, uint baseTokensFilled) {
        Orders.Order memory order = ordersData.orders[orderKey];
        return (order.prev, order.next, uint(order.orderType), order.maker, order.baseToken, order.quoteToken, order.price, order.expiry, order.baseTokens, order.baseTokensFilled);
    }

    function addOrder(Orders.OrderType orderType, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens) public returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, */ uint _baseTokensOnOrder, bytes32 _orderKey) {
        // BK TODO - Add check for expiry
        _baseTokensOnOrder = baseTokens;

        bytes32 matchingOrderKey = ordersData.getBestMatchingOrder(orderType, baseToken, quoteToken, price);
        emit LogInfo("addOrder: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        while (matchingOrderKey != SENTINEL && _baseTokensOnOrder > 0) {
            uint _baseTokens;
            uint _quoteTokens;
            Orders.Order storage order = ordersData.orders[matchingOrderKey];
            emit LogInfo("addOrder: order", order.baseTokens, matchingOrderKey, "", order.maker);
            (_baseTokens, _quoteTokens) = calculateOrder(matchingOrderKey, _baseTokensOnOrder, msg.sender);
            emit LogInfo("addOrder: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            emit LogInfo("addOrder: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            if (_baseTokens > 0 && _quoteTokens > 0) {
                order.baseTokensFilled = order.baseTokensFilled.add(_baseTokens);
                uint takerFeeTokens;

                if (orderType == Orders.OrderType.SELL) {
                    emit LogInfo("addOrder: order SELL", 0, 0x0, "", address(0));

                    takerFeeTokens = _quoteTokens.mul(takerFee).div(TENPOW18);
                    // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens, _quoteTokens.sub(takerFeeTokens), 0, takerFeeTokens, order.baseTokensFilled);

                    transferFrom(order.baseToken, msg.sender, order.maker, _baseTokens);
                    transferFrom(order.quoteToken, order.maker, msg.sender, _quoteTokens.sub(takerFeeTokens));
                    if (takerFeeTokens > 0) {
                        transferFrom(order.quoteToken, order.maker, feeAccount, takerFeeTokens);
                    }

                } else {
                    emit LogInfo("addOrder: order BUY", 0, 0x0, "", address(0));

                    takerFeeTokens = _baseTokens.mul(takerFee).div(TENPOW18);
                    // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, order.baseTokensFilled);

                    transferFrom(order.quoteToken, msg.sender, order.maker, _quoteTokens);
                    transferFrom(order.baseToken, order.maker, msg.sender, _baseTokens.sub(takerFeeTokens));
                    if (takerFeeTokens > 0) {
                        transferFrom(order.baseToken, order.maker, feeAccount, takerFeeTokens);
                    }
                }
                _baseTokensOnOrder = _baseTokensOnOrder.sub(_baseTokens);
                // _baseTokensFilled = _baseTokensFilled.add(_baseTokens);
                // _quoteTokensFilled = _quoteTokensFilled.add(_quoteTokens);
                ordersData.updateBestMatchingOrder(orderType, baseToken, quoteToken, price, matchingOrderKey);
                // matchingOrderKey = SENTINEL;
                matchingOrderKey = ordersData.getBestMatchingOrder(orderType, baseToken, quoteToken, price);
            }
        }
        if (_baseTokensOnOrder > 0) {
            _orderKey = ordersData.add(Orders.OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, expiry, _baseTokensOnOrder);
        }
    }

    function calculateOrder(bytes32 _matchingOrderKey, uint amountBaseTokens, address taker) public returns (uint baseTokens, uint quoteTokens) {
        Orders.Order storage matchingOrder = ordersData.orders[_matchingOrderKey];
        require(now <= matchingOrder.expiry);

        // // Maker buying base, needs to have amount in quote = base x price
        // // Taker selling base, needs to have amount in base
        if (matchingOrder.orderType == Orders.OrderType.BUY) {
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
            if (matchingOrder.orderType == Orders.OrderType.BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
        } else if (matchingOrder.orderType == Orders.OrderType.SELL) {
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Sell: availableTokens(matchingOrder.baseToken, matchingOrder.maker)", _availableBaseTokens, 0x0, "", matchingOrder.maker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.orderType == Orders.OrderType.SELL && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
            if (matchingOrder.orderType == Orders.OrderType.BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
        bytes32 oldKey = Orders.orderKey(Orders.OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, oldPrice, expiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.orderKey(Orders.OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, newPrice, expiry);
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
        bytes32 oldKey = Orders.orderKey(Orders.OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, oldExpiry);
        Order storage oldOrder = orders[oldKey];
        require(oldOrder.maker == msg.sender);
        bytes32 newKey = Orders.orderKey(Orders.OrderType(uint(orderType)), msg.sender, baseToken, quoteToken, price, newExpiry);
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
        // Order storage order = orders[key];
        // require(order.maker == msg.sender);
        // order.baseTokens = order.baseTokensFilled;
        // emit OrderRemoved(key);
        ordersData.remove(key, msg.sender);
    }

    function transferFrom(address token, address from, address to, uint tokens) internal {
        TokenWhitelistStatus whitelistStatus = tokenWhitelist[token];
        // Difference in gas for 2 x maker fills - wl 293405, no wl 326,112
        if (whitelistStatus == TokenWhitelistStatus.WHITELIST) {
            require(ERC20Interface(token).transferFrom(from, to, tokens));
        } else if (whitelistStatus == TokenWhitelistStatus.NONE) {
            uint balanceToBefore = ERC20Interface(token).balanceOf(to);
            require(ERC20Interface(token).transferFrom(from, to, tokens));
            uint balanceToAfter = ERC20Interface(token).balanceOf(to);
            require(balanceToBefore.add(tokens) == balanceToAfter);
        } else {
            revert();
        }
    }

    function availableTokens(address token, address wallet) internal view returns (uint _tokens) {
        _tokens = ERC20Interface(token).allowance(wallet, address(this));
        _tokens = _tokens.min(ERC20Interface(token).balanceOf(wallet));
    }
}
