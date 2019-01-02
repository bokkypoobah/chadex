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

    // length = 4 + 7 * 32 = 228
    uint private constant tradeDataLength = 228;
    function receiveApproval(address _from, uint256 _tokens, address _token, bytes memory _data) public {
        emit LogInfo("receiveApproval: from", 0, 0x0, "", _from);
        emit LogInfo("receiveApproval: tokens & token", _tokens, 0x0, "", _token);
        uint length;
        bytes4 functionSignature;
        uint parameter1;
        uint parameter2;
        uint parameter3;
        uint parameter4;
        uint parameter5;
        uint parameter6;
        uint parameter7;
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
        emit LogInfo("receiveApproval: p1 orderType", parameter1, 0x0, "", address(0));
        emit LogInfo("receiveApproval: p2 baseToken", 0, 0x0, "", address(parameter2));
        emit LogInfo("receiveApproval: p3 quoteToken", 0, 0x0, "", address(parameter3));
        emit LogInfo("receiveApproval: p4 price", parameter4, 0x0, "", address(0));
        emit LogInfo("receiveApproval: p5 expiry", parameter5, 0x0, "", address(0));
        emit LogInfo("receiveApproval: p6 baseTokens", parameter6, 0x0, "", address(0));
        emit LogInfo("receiveApproval: p7 uiFeeAccount", 0, 0x0, "", address(parameter7));

        if (functionSignature == tradeSig) {
            require(length >= tradeDataLength);
            // TradeInfo memory tradeInfo = TradeInfo(_from, uint(parameter1), address(uint(parameter2)), address(uint(parameter3)), uint(parameter4), uint(parameter5), uint(parameter6), address(uint(parameter7)));
            _trade(TradeInfo(_from, parameter1, address(parameter2), address(parameter3), parameter4, parameter5, parameter6, address(parameter7)));
            // _trade(tradeInfo);
            // _trade(_from, uint(parameter1), address(uint(parameter2)), address(uint(parameter3)), uint(parameter4), uint(parameter5), uint(parameter6), address(uint(parameter7)));
        }
//        function addOrder(uint orderType, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {

    }

    // buy(address,address,uint256,uint256,uint256,address)
    // sell(address,address,uint256,uint256,uint256,address)
    // function buy(address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
    //     return trade(ORDERTYPE_BUY, baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount);
    // }
    // function sell(address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
    //     return trade(ORDERTYPE_SELL, baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount);
    // }

    struct TradeInfo {
        address taker;
        uint orderFlag;
        address baseToken;
        address quoteToken;
        uint price;
        uint expiry;
        uint baseTokens;
        address uiFeeAccount;
    }

    // trade(uint256,address,address,uint256,uint256,uint256,address)
    // web3.sha3("trade(uint256,address,address,uint256,uint256,uint256,address)").substring(0, 10)
    // => "0xcbb924e2"
    bytes4 public constant tradeSig = "\xcb\xb9\x24\xe2";
    function trade(uint orderFlag, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
        TradeInfo memory tradeInfo = TradeInfo(msg.sender, orderFlag | ORDERFLAG_ADDORDER, baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount);
        return _trade(tradeInfo);
        // return _trade(msg.sender, orderFlag, baseToken, quoteToken, price, expiry, baseTokens, uiFeeAccount);
    }
    function _trade(TradeInfo memory tradeInfo) internal returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
    // function _trade(address taker, uint orderFlag, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (/*uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, */ bytes32 _orderKey) {
        uint orderType = tradeInfo.orderFlag & ORDERFLAG_BUYSELL;
        uint matchingPriceKey;
        bytes32 matchingOrderKey;
        (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(orderType, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price);
        emit LogInfo("_trade: matchingOrderKey", 0, matchingOrderKey, "", address(0));

        while (matchingOrderKey != ORDERKEY_SENTINEL && tradeInfo.baseTokens > 0) {
            // uint _baseTokens;
            // uint _quoteTokens;
            uint[2] memory tokens; // 0 = baseToken, 1 = quoteToken
            bool _orderFilled;
            Orders.Order storage order = orders[matchingOrderKey];
            // emit LogInfo("_trade: order", order.baseTokens, matchingOrderKey, "", order.maker);
            // (_baseTokens, _quoteTokens, _orderFilled) = calculateOrder(matchingOrderKey, baseTokens, msg.sender);
            (tokens, _orderFilled) = calculateOrder(matchingOrderKey, tradeInfo.baseTokens, tradeInfo.taker);
            // emit LogInfo("_trade: order._baseTokens", _baseTokens, matchingOrderKey, "", order.maker);
            // emit LogInfo("_trade: order._quoteTokens", _quoteTokens, matchingOrderKey, "", order.maker);

            // if (_baseTokens > 0 && _quoteTokens > 0) {
            if (tokens[0] > 0 && tokens[1] > 0) {
                // order.baseTokensFilled = order.baseTokensFilled.add(_baseTokens);
                order.baseTokensFilled = order.baseTokensFilled.add(tokens[0]);
                // trade(orderType, msg.sender, order.maker, uiFeeAccount, baseToken, quoteToken, _baseTokens, _quoteTokens);
                // trade(orderType, msg.sender, order.maker, uiFeeAccount, baseToken, quoteToken, tokens);
                transferTokens(tradeInfo, orderType, order.maker, tokens, matchingOrderKey);
                tradeInfo.baseTokens = tradeInfo.baseTokens.sub(tokens[0]);
                // _baseTokensFilled = _baseTokensFilled.add(_baseTokens);
                // _quoteTokensFilled = _quoteTokensFilled.add(_quoteTokens);
                _updateBestMatchingOrder(orderType, tradeInfo.baseToken, tradeInfo.quoteToken, matchingPriceKey, matchingOrderKey, _orderFilled);
                // matchingOrderKey = ORDERKEY_SENTINEL;
                (matchingPriceKey, matchingOrderKey) = _getBestMatchingOrder(orderType, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price);
            }
        }
        if (tradeInfo.baseTokens > 0 && ((tradeInfo.orderFlag & ORDERFLAG_ADDORDER) == ORDERFLAG_ADDORDER)) {
            require(tradeInfo.expiry > now);
            _orderKey = _addOrder(orderType, tradeInfo.taker, tradeInfo.baseToken, tradeInfo.quoteToken, tradeInfo.price, tradeInfo.expiry, tradeInfo.baseTokens);
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
            emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens", matchingOrder.baseTokens, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokensFilled", matchingOrder.baseTokensFilled, 0x0, "", address(0));
            emit LogInfo("calculateOrder Maker Buy: amountBaseTokens", amountBaseTokens, 0x0, "", address(0));
            uint _availableBaseTokens = availableTokens(matchingOrder.baseToken, taker);
            emit LogInfo("calculateOrder Maker Buy: availableTokens(matchingOrder.baseToken, taker)", _availableBaseTokens, 0x0, "", taker);
            // Update maker matchingOrder with currently available tokens
            if (matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Maker Buy: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            baseTokens = baseTokens.min(_availableBaseTokens);
            emit LogInfo("calculateOrder Maker Buy: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, taker))", baseTokens, 0x0, "", taker);

            emit LogInfo("calculateOrder Maker Buy: quoteTokens = baseTokens x price / 1e18", baseTokens.mul(matchingOrder.price).div(TENPOW18), 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, matchingOrder.maker);
            emit LogInfo("calculateOrder Maker Buy: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", matchingOrder.maker);
            if (matchingOrder.orderType == ORDERTYPE_BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            quoteTokens = quoteTokens.min(_availableQuoteTokens);
            emit LogInfo("calculateOrder Maker Buy: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, matchingOrder.maker))", quoteTokens, 0x0, "", matchingOrder.maker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            baseTokens = baseTokens.min(quoteTokens.mul(TENPOW18).div(matchingOrder.price));
            emit LogInfo("calculateOrder Maker Buy: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
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
            if (matchingOrder.orderType == ORDERTYPE_SELL && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
                matchingOrder.baseTokens = _availableBaseTokens + matchingOrder.baseTokensFilled;
                emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
                // ordersData.orders[_matchingOrderKey].baseTokens = matchingOrder.baseTokens;
            } else {
                emit LogInfo("calculateOrder Maker Sell: matchingOrder.baseTokens NOT reduced due to available tokens", matchingOrder.baseTokens, 0x0, "", address(0));
            }
            baseTokens = matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled).min(amountBaseTokens);
            baseTokens = baseTokens.min(_availableBaseTokens);
            emit LogInfo("calculateOrder Maker Sell: baseTokens = baseTokens.min(availableTokens(matchingOrder.baseToken, matchingOrder.maker))", baseTokens, 0x0, "", matchingOrder.maker);

            emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", baseTokens.mul(matchingOrder.price).div(TENPOW18), 0x0, "", address(0));
            uint _availableQuoteTokens = availableTokens(matchingOrder.quoteToken, taker);
            emit LogInfo("calculateOrder Maker Sell: availableTokens(matchingOrder.quoteToken, matchingOrder.maker)", _availableQuoteTokens, 0x0, "", taker);
            if (matchingOrder.orderType == ORDERTYPE_BUY && matchingOrder.baseTokens.sub(matchingOrder.baseTokensFilled) > _availableBaseTokens) {
            }
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            quoteTokens = quoteTokens.min(_availableQuoteTokens);
            emit LogInfo("calculateOrder Maker Sell: quoteTokens = quoteTokens.min(availableTokens(matchingOrder.quoteToken, taker))", quoteTokens, 0x0, "", taker);
            // TODO: Add code to collect dust. E.g. > 14 decimal places, check for (dp - 14) threshold to also transfer remaining dust

            baseTokens = baseTokens.min(quoteTokens.mul(TENPOW18).div(matchingOrder.price));
            emit LogInfo("calculateOrder Maker Sell: baseTokens = min(baseTokens, quoteTokens x 1e18 / price)", baseTokens, 0x0, "", address(0));
            quoteTokens = baseTokens.mul(matchingOrder.price).div(TENPOW18);
            emit LogInfo("calculateOrder Maker Sell: quoteTokens = baseTokens x price / 1e18", quoteTokens, 0x0, "", address(0));
        }
        // TODO BK
        _orderFilled = true;
        tokens[0] = baseTokens;
        tokens[1] = quoteTokens;
    }


    // function trade(uint orderType, address taker, address maker, address uiFeeAccount, address baseToken, address quoteToken, uint[2] memory tokens) internal {
    function transferTokens(TradeInfo memory tradeInfo, uint orderType, address maker, uint[2] memory tokens, bytes32 matchingOrderKey) internal {
        uint takerFeeTokens;
        uint _baseTokens = tokens[0];
        uint _quoteTokens = tokens[1];

        // TODO
        uint __orderBaseTokensFilled = 0;

        if (orderType == ORDERTYPE_BUY) {
            emit LogInfo("transferTokens: BUY", 0, 0x0, "", address(0));

            takerFeeTokens = _baseTokens.mul(takerFee).div(TENPOW18);
            // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, order.baseTokensFilled);
            // emit Trade(__matchingOrderKey, orderType, taker, maker, _baseTokens, baseToken, quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, __orderBaseTokensFilled);
            emit Trade(matchingOrderKey, orderType, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens.sub(takerFeeTokens), _quoteTokens, takerFeeTokens, 0, __orderBaseTokensFilled);

            transferFrom(tradeInfo.quoteToken, tradeInfo.taker, maker, _quoteTokens);
            transferFrom(tradeInfo.baseToken, maker, tradeInfo.taker, _baseTokens.sub(takerFeeTokens));
            if (takerFeeTokens > 0) {
                if (feeAccount == tradeInfo.uiFeeAccount || takerFeeTokens == 1) {
                    transferFrom(tradeInfo.baseToken, maker, feeAccount, takerFeeTokens);
                } else {
                    transferFrom(tradeInfo.baseToken, maker, tradeInfo.uiFeeAccount, takerFeeTokens / 2);
                    transferFrom(tradeInfo.baseToken, maker, feeAccount, takerFeeTokens - takerFeeTokens / 2);
                }
            }
        } else {
            emit LogInfo("transferTokens: SELL", 0, 0x0, "", address(0));

            takerFeeTokens = _quoteTokens.mul(takerFee).div(TENPOW18);
            // emit Trade(matchingOrderKey, uint(orderType), msg.sender, order.maker, baseTokens, order.baseToken, order.quoteToken, _baseTokens, _quoteTokens.sub(takerFeeTokens), 0, takerFeeTokens, order.baseTokensFilled);
            emit Trade(matchingOrderKey, orderType, tradeInfo.taker, maker, _baseTokens, tradeInfo.baseToken, tradeInfo.quoteToken, _baseTokens, _quoteTokens.sub(takerFeeTokens), takerFeeTokens, 0, __orderBaseTokensFilled);

            transferFrom(tradeInfo.baseToken, tradeInfo.taker, maker, _baseTokens);
            transferFrom(tradeInfo.quoteToken, maker, tradeInfo.taker, _quoteTokens.sub(takerFeeTokens));
            if (takerFeeTokens > 0) {
                if (feeAccount == tradeInfo.uiFeeAccount || takerFeeTokens == 1) {
                    transferFrom(tradeInfo.quoteToken, maker, feeAccount, takerFeeTokens);
                } else {
                    transferFrom(tradeInfo.quoteToken, maker, tradeInfo.uiFeeAccount, takerFeeTokens / 2);
                    transferFrom(tradeInfo.quoteToken, maker, feeAccount, takerFeeTokens - takerFeeTokens / 2);
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
