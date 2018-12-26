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

import "Orders.sol";


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
