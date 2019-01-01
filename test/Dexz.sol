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
import "ApproveAndCallFallback.sol";


// ----------------------------------------------------------------------------
// Dexz contract
// ----------------------------------------------------------------------------
contract Dexz is Orders, ApproveAndCallFallback {
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    event Trade(bytes32 indexed key, uint orderType, address indexed taker, address indexed maker, uint amount, address baseToken, address quoteToken, uint baseTokens, uint quoteTokens, uint feeBaseTokens, uint feeQuoteTokens, uint baseTokensFilled);

    constructor(address _feeAccount) public Orders(_feeAccount) {
    }

    function receiveApproval(address _from, uint256 _tokens, address _token, bytes memory _data) public {
        emit LogInfo("receiveApproval: from", 0, 0x0, "", _from);
        emit LogInfo("receiveApproval: tokens & token", _tokens, 0x0, "", _token);
        bytes32 dataBytes32;
        for (uint i = 0; i < _data.length && i < 32; i++) {
            dataBytes32 |= bytes32(_data[i] & 0xff) >> (i * 8);
        }
        emit LogInfo("receiveApproval: data", 0, dataBytes32, "", address(0));
        uint length;
        bytes4 functionSignature;
        bytes32 parameter1;
        bytes32 parameter2;
        bytes32 parameter3;
        bytes32 parameter4;
        bytes32 parameter5;
        bytes32 parameter6;
        bytes32 parameter7;
        assembly {
            length := mload(_data)
            functionSignature := mload(add(_data, 0x20))
            parameter1 := mload(add(_data, 0x24))
            parameter2 := mload(add(_data, 0x44))
            parameter3 := mload(add(_data, 0x64))
            parameter4 := mload(add(_data, 0x84))
            parameter5 := mload(add(_data, 0xA4))
            parameter6 := mload(add(_data, 0xC4))
            parameter7 := mload(add(_data, 0xE4))
        }
        emit LogInfo("receiveApproval: length", length, 0x0, "", address(0));
        emit LogInfo("receiveApproval: functionSignature", 0, bytes32(functionSignature), "", address(0));
        emit LogInfo("receiveApproval: parameter1", 0, bytes32(parameter1), "", address(0));
        emit LogInfo("receiveApproval: parameter2", 0, bytes32(parameter2), "", address(0));
        emit LogInfo("receiveApproval: parameter3", 0, bytes32(parameter3), "", address(0));
        emit LogInfo("receiveApproval: parameter4", 0, bytes32(parameter4), "", address(0));
        emit LogInfo("receiveApproval: parameter4", 0, bytes32(parameter5), "", address(0));
        emit LogInfo("receiveApproval: parameter4", 0, bytes32(parameter6), "", address(0));
        emit LogInfo("receiveApproval: parameter4", 0, bytes32(parameter7), "", address(0));

//        function addOrder(uint orderType, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {


    }

    // function trade(uint orderType, address taker, address maker, address uiFeeAccount, address baseToken, address quoteToken, uint[2] memory tokens) internal {
    function trade(uint orderType, address[5] memory addresses, uint[2] memory tokens, bytes32 matchingOrderKey) internal {
        uint takerFeeTokens;
        uint _baseTokens = tokens[0];
        uint _quoteTokens = tokens[1];

        // address taker = addresses[0];
        // address maker = addresses[1];
        // address uiFeeAccount = addresses[2];
        // address baseToken = addresses[3];
        // address quoteToken = addresses[4];

        // TODO
        uint __orderBaseTokensFilled = 0;

        if (orderType == ORDERTYPE_BUY) {
            emit LogInfo("trade: BUY", 0, 0x0, "", address(0));

            takerFeeTokens = _baseTokens.mul(takerFee).div(TENPOW18);
            // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, order.baseTokensFilled);
            // emit Trade(__matchingOrderKey, orderType, taker, maker, _baseTokens, baseToken, quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, __orderBaseTokensFilled);
            emit Trade(matchingOrderKey, orderType, addresses[0], addresses[1], _baseTokens, addresses[3], addresses[4], _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, __orderBaseTokensFilled);

            transferFrom(addresses[4], addresses[0], addresses[1], _quoteTokens);
            transferFrom(addresses[3], addresses[1], addresses[0], _baseTokens.sub(takerFeeTokens));
            if (takerFeeTokens > 0) {
                if (feeAccount == addresses[2] || takerFeeTokens == 1) {
                    transferFrom(addresses[3], addresses[1], feeAccount, takerFeeTokens);
                } else {
                    transferFrom(addresses[3], addresses[1], addresses[2], takerFeeTokens / 2);
                    transferFrom(addresses[3], addresses[1], feeAccount, takerFeeTokens - takerFeeTokens / 2);
                }
            }
        } else {
            emit LogInfo("trade: SELL", 0, 0x0, "", address(0));

            takerFeeTokens = _quoteTokens.mul(takerFee).div(TENPOW18);
            // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens, _quoteTokens.sub(takerFeeTokens), 0, takerFeeTokens, order.baseTokensFilled);
            emit Trade(matchingOrderKey, orderType, addresses[0], addresses[1], _baseTokens, addresses[3], addresses[4], _baseTokens, _quoteTokens.sub(takerFeeTokens), takerFeeTokens, 0, __orderBaseTokensFilled);

            transferFrom(addresses[3], addresses[0], addresses[1], _baseTokens);
            transferFrom(addresses[4], addresses[1], addresses[0], _quoteTokens.sub(takerFeeTokens));
            if (takerFeeTokens > 0) {
                if (feeAccount == addresses[2] || takerFeeTokens == 1) {
                    transferFrom(addresses[4], addresses[1], feeAccount, takerFeeTokens);
                } else {
                    transferFrom(addresses[4], addresses[1], addresses[2], takerFeeTokens / 2);
                    transferFrom(addresses[4], addresses[1], feeAccount, takerFeeTokens - takerFeeTokens / 2);
                }
            }
        }
    }

    function addOrder(uint orderType, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
        uint matchingPriceKey;
        bytes32 matchingOrderKey;
        (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(orderType, baseToken, quoteToken, price);
        emit LogInfo("addOrder: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        while (matchingOrderKey != ORDERKEY_SENTINEL && baseTokens > 0) {
            // uint _baseTokens;
            // uint _quoteTokens;
            uint[2] memory tokens; // 0 = baseToken, 1 = quoteToken
            address[5] memory addresses; // 0 = taker, 1 = maker, 2 = uiFeeAccount, 3 = baseToken, 4 = quoteToken
            bool _orderFilled;
            Orders.Order storage order = orders[matchingOrderKey];
            // emit LogInfo("addOrder: order", order.baseTokens, matchingOrderKey, "", order.maker);
            // (_baseTokens, _quoteTokens, _orderFilled) = calculateOrder(matchingOrderKey, baseTokens, msg.sender);
            (tokens, _orderFilled) = calculateOrder(matchingOrderKey, baseTokens, msg.sender);
            // emit LogInfo("addOrder: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            // emit LogInfo("addOrder: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            // if (_baseTokens > 0 && _quoteTokens > 0) {
            if (tokens[0] > 0 && tokens[1] > 0) {
                // order.baseTokensFilled = order.baseTokensFilled.add(_baseTokens);
                order.baseTokensFilled = order.baseTokensFilled.add(tokens[0]);
                // trade(orderType, msg.sender, order.maker, uiFeeAccount, baseToken, quoteToken, _baseTokens, _quoteTokens);
                addresses[0] = msg.sender;
                addresses[1] = order.maker;
                addresses[2] = uiFeeAccount;
                addresses[3] = baseToken;
                addresses[4] = quoteToken;
                // trade(orderType, msg.sender, order.maker, uiFeeAccount, baseToken, quoteToken, tokens);
                trade(orderType, addresses, tokens, matchingOrderKey);
                baseTokens = baseTokens.sub(tokens[0]);
                // _baseTokensFilled = _baseTokensFilled.add(_baseTokens);
                // _quoteTokensFilled = _quoteTokensFilled.add(_quoteTokens);
                _updateBestMatchingOrder(orderType, baseToken, quoteToken, matchingPriceKey, matchingOrderKey, _orderFilled);
                // matchingOrderKey = ORDERKEY_SENTINEL;
                (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(orderType, baseToken, quoteToken, price);
            }
        }
        if (baseTokens > 0) {
            require(expiry > now);
            _orderKey = _addOrder(orderType, msg.sender, baseToken, quoteToken, price, expiry, baseTokens);
        }
    }

    function calculateOrder(bytes32 _matchingOrderKey, uint amountBaseTokens, address taker) internal returns (uint[2] memory tokens, bool _orderFilled) {
        Orders.Order storage matchingOrder = orders[_matchingOrderKey];
        require(now <= matchingOrder.expiry);
        uint baseTokens;
        uint quoteTokens;

        // // Maker buying base, needs to have amount in quote = base x price
        // // Taker selling base, needs to have amount in base
        if (matchingOrder.orderType == ORDERTYPE_BUY) {
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
            if (matchingOrder.orderType == ORDERTYPE_BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
        } else if (matchingOrder.orderType == ORDERTYPE_SELL) {
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Sell: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Sell: availableTokens(matchingOrder.baseToken, matchingOrder.maker)", _availableBaseTokens, 0x0, "", matchingOrder.maker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.orderType == ORDERTYPE_SELL && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
            if (matchingOrder.orderType == ORDERTYPE_BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
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
        // TODO BK
        _orderFilled = true;
        tokens[0] = baseTokens;
        tokens[1] = quoteTokens;
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
