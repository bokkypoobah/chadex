// 16 Dec 2018 11:56 AEDT ETH/USD from CMC and ethgasstation.info
var ethPriceUSD = 135.91;
var defaultGasPrice = web3.toWei(5, "gwei");

// -----------------------------------------------------------------------------
// Accounts
// -----------------------------------------------------------------------------
var accounts = [];
var accountNames = {};

addAccount(eth.accounts[0], "Miner");
addAccount(eth.accounts[1], "Deployer");
addAccount(eth.accounts[2], "User1");
addAccount(eth.accounts[3], "User2");
addAccount(eth.accounts[4], "User3");
addAccount(eth.accounts[5], "User4");
addAccount(eth.accounts[6], "User5");
addAccount(eth.accounts[7], "User6");
addAccount(eth.accounts[8], "Fee");
addAccount(eth.accounts[9], "UIFee");

var miner = eth.accounts[0];
var deployer = eth.accounts[1];
var user1 = eth.accounts[2];
var user2 = eth.accounts[3];
var user3 = eth.accounts[4];
var user4 = eth.accounts[5];
var user5 = eth.accounts[6];
var user6 = eth.accounts[7];
var feeAccount = eth.accounts[8];
var uiFeeAccount = eth.accounts[9];

console.log("DATA: var miner=\"" + eth.accounts[0] + "\";");
console.log("DATA: var deployer=\"" + eth.accounts[1] + "\";");
console.log("DATA: var user1=\"" + eth.accounts[2] + "\";");
console.log("DATA: var user2=\"" + eth.accounts[3] + "\";");
console.log("DATA: var user3=\"" + eth.accounts[4] + "\";");
console.log("DATA: var user4=\"" + eth.accounts[5] + "\";");
console.log("DATA: var user5=\"" + eth.accounts[6] + "\";");
console.log("DATA: var user6=\"" + eth.accounts[7] + "\";");
console.log("DATA: var feeAccount=\"" + eth.accounts[8] + "\";");
console.log("DATA: var uiFeeAccount=\"" + eth.accounts[9] + "\";");

var baseBlock = eth.blockNumber;

function unlockAccounts(password) {
  for (var i = 0; i < eth.accounts.length && i < accounts.length; i++) {
    personal.unlockAccount(eth.accounts[i], password, 100000);
    if (i > 0 && eth.getBalance(eth.accounts[i]) == 0) {
      personal.sendTransaction({from: eth.accounts[0], to: eth.accounts[i], value: web3.toWei(1000000, "ether")});
    }
  }
  while (txpool.status.pending > 0) {
  }
  baseBlock = eth.blockNumber;
}

function addAccount(account, accountName) {
  accounts.push(account);
  accountNames[account] = accountName;
  addAddressNames(account, accountName);
}

addAddressNames("0x0000000000000000000000000000000000000000", "Null");

//-----------------------------------------------------------------------------
// Token Contracts
//-----------------------------------------------------------------------------
var _tokenContractAddresses = [];
var _tokenContractAbis = [];
var _tokens = [null, null, null, null];
var _symbols = ["0", "1", "2", "3"];
var _decimals = [18, 18, 18, 18];

function addTokenContractAddressAndAbi(i, address, abi) {
  _tokenContractAddresses[i] = address;
  _tokenContractAbis[i] = abi;
  _tokens[i] = web3.eth.contract(abi).at(address);
  _symbols[i] = _tokens[i].symbol();
  _decimals[i] = _tokens[i].decimals();
}


//-----------------------------------------------------------------------------
//Account ETH and token balances
//-----------------------------------------------------------------------------
function printBalances() {
  var i = 0;
  var j;
  var totalTokenBalances = [new BigNumber(0), new BigNumber(0), new BigNumber(0), new BigNumber(0)];
  console.log("RESULT:  # Account                                             EtherBalanceChange               " + padLeft(_symbols[0], 16) + "               " + padLeft(_symbols[1], 16) + " Name");
  console.log("RESULT:                                                                                         " + padLeft(_symbols[2], 16) + "               " + padLeft(_symbols[3], 16));
  console.log("RESULT: -- ------------------------------------------ --------------------------- ------------------------------ ------------------------------ ---------------------------");
  accounts.forEach(function(e) {
    var etherBalanceBaseBlock = eth.getBalance(e, baseBlock);
    var etherBalance = web3.fromWei(eth.getBalance(e).minus(etherBalanceBaseBlock), "ether");
    var tokenBalances = [];
    for (j = 0; j < 4; j++) {
      tokenBalances[j] = _tokens[j] == null ? new BigNumber(0) : _tokens[j].balanceOf(e).shift(-_decimals[j]);
      totalTokenBalances[j] = totalTokenBalances[j].add(tokenBalances[j]);
    }
    console.log("RESULT: " + pad2(i) + " " + e  + " " + pad(etherBalance) + " " +
      padToken(tokenBalances[0], _decimals[0]) + " " + padToken(tokenBalances[1], _decimals[1]) + " " + accountNames[e]);
      console.log("RESULT:                                                                           " +
        padToken(tokenBalances[2], _decimals[2]) + " " + padToken(tokenBalances[3], _decimals[3]));
    i++;
  });
  console.log("RESULT: -- ------------------------------------------ --------------------------- ------------------------------ ------------------------------ ---------------------------");
  console.log("RESULT:                                                                           " + padToken(totalTokenBalances[0], _decimals[0]) + " " + padToken(totalTokenBalances[1], _decimals[1]) + " Total Token Balances");
  console.log("RESULT:                                                                           " + padToken(totalTokenBalances[2], _decimals[2]) + " " + padToken(totalTokenBalances[3], _decimals[3]));
  console.log("RESULT: -- ------------------------------------------ --------------------------- ------------------------------ ------------------------------ ---------------------------");
  console.log("RESULT: ");
}

function pad2(s) {
  var o = s.toFixed(0);
  while (o.length < 2) {
    o = " " + o;
  }
  return o;
}

function pad(s) {
  var o = s.toFixed(18);
  while (o.length < 27) {
    o = " " + o;
  }
  return o;
}

function padToken(s, decimals) {
  var o = s.toFixed(decimals);
  var l = parseInt(decimals)+12;
  while (o.length < l) {
    o = " " + o;
  }
  return o;
}

function padLeft(s, n) {
  var o = s;
  while (o.length < n) {
    o = " " + o;
  }
  return o;
}


// -----------------------------------------------------------------------------
// Transaction status
// -----------------------------------------------------------------------------
function printTxData(name, txId) {
  var tx = eth.getTransaction(txId);
  var txReceipt = eth.getTransactionReceipt(txId);
  var gasPrice = tx.gasPrice;
  var gasCostETH = tx.gasPrice.mul(txReceipt.gasUsed).div(1e18);
  var gasCostUSD = gasCostETH.mul(ethPriceUSD);
  var block = eth.getBlock(txReceipt.blockNumber);
  console.log("RESULT: " + name + " status=" + txReceipt.status + (txReceipt.status == 0 ? " Failure" : " Success") + " gas=" + tx.gas +
    " gasUsed=" + txReceipt.gasUsed + " costETH=" + gasCostETH + " costUSD=" + gasCostUSD +
    " @ ETH/USD=" + ethPriceUSD + " gasPrice=" + web3.fromWei(gasPrice, "gwei") + " gwei block=" +
    txReceipt.blockNumber + " txIx=" + tx.transactionIndex + " txId=" + txId +
    " @ " + block.timestamp + " " + new Date(block.timestamp * 1000).toUTCString());
}

function assertEtherBalance(account, expectedBalance) {
  var etherBalance = web3.fromWei(eth.getBalance(account), "ether");
  if (etherBalance == expectedBalance) {
    console.log("RESULT: OK " + account + " has expected balance " + expectedBalance);
  } else {
    console.log("RESULT: FAILURE " + account + " has balance " + etherBalance + " <> expected " + expectedBalance);
  }
}

function failIfTxStatusError(tx, msg) {
  var status = eth.getTransactionReceipt(tx).status;
  if (status == 0) {
    console.log("RESULT: FAIL " + msg);
    return 0;
  } else {
    console.log("RESULT: PASS " + msg);
    return 1;
  }
}

function passIfTxStatusError(tx, msg) {
  var status = eth.getTransactionReceipt(tx).status;
  if (status == 1) {
    console.log("RESULT: FAIL " + msg);
    return 0;
  } else {
    console.log("RESULT: PASS " + msg);
    return 1;
  }
}

function gasEqualsGasUsed(tx) {
  var gas = eth.getTransaction(tx).gas;
  var gasUsed = eth.getTransactionReceipt(tx).gasUsed;
  return (gas == gasUsed);
}

function failIfGasEqualsGasUsed(tx, msg) {
  var gas = eth.getTransaction(tx).gas;
  var gasUsed = eth.getTransactionReceipt(tx).gasUsed;
  if (gas == gasUsed) {
    console.log("RESULT: FAIL " + msg);
    return 0;
  } else {
    console.log("RESULT: PASS " + msg);
    return 1;
  }
}

function passIfGasEqualsGasUsed(tx, msg) {
  var gas = eth.getTransaction(tx).gas;
  var gasUsed = eth.getTransactionReceipt(tx).gasUsed;
  if (gas == gasUsed) {
    console.log("RESULT: PASS " + msg);
    return 1;
  } else {
    console.log("RESULT: FAIL " + msg);
    return 0;
  }
}

function failIfGasEqualsGasUsedOrContractAddressNull(contractAddress, tx, msg) {
  if (contractAddress == null) {
    console.log("RESULT: FAIL " + msg);
    return 0;
  } else {
    var gas = eth.getTransaction(tx).gas;
    var gasUsed = eth.getTransactionReceipt(tx).gasUsed;
    if (gas == gasUsed) {
      console.log("RESULT: FAIL " + msg);
      return 0;
    } else {
      console.log("RESULT: PASS " + msg);
      return 1;
    }
  }
}


//-----------------------------------------------------------------------------
// Wait one block
//-----------------------------------------------------------------------------
function waitOneBlock(oldCurrentBlock) {
  while (eth.blockNumber <= oldCurrentBlock) {
  }
  console.log("RESULT: Waited one block");
  console.log("RESULT: ");
  return eth.blockNumber;
}


//-----------------------------------------------------------------------------
// Pause for {x} seconds
//-----------------------------------------------------------------------------
function pause(message, addSeconds) {
  var time = new Date((parseInt(new Date().getTime()/1000) + addSeconds) * 1000);
  console.log("RESULT: Pausing '" + message + "' for " + addSeconds + "s=" + time + " now=" + new Date());
  while ((new Date()).getTime() <= time.getTime()) {
  }
  console.log("RESULT: Paused '" + message + "' for " + addSeconds + "s=" + time + " now=" + new Date());
  console.log("RESULT: ");
}


//-----------------------------------------------------------------------------
//Wait until some unixTime + additional seconds
//-----------------------------------------------------------------------------
function waitUntil(message, unixTime, addSeconds) {
  var t = parseInt(unixTime) + parseInt(addSeconds) + parseInt(1);
  var time = new Date(t * 1000);
  console.log("RESULT: Waiting until '" + message + "' at " + unixTime + "+" + addSeconds + "s=" + time + " now=" + new Date());
  while ((new Date()).getTime() <= time.getTime()) {
  }
  console.log("RESULT: Waited until '" + message + "' at at " + unixTime + "+" + addSeconds + "s=" + time + " now=" + new Date());
  console.log("RESULT: ");
}


//-----------------------------------------------------------------------------
//Wait until some block
//-----------------------------------------------------------------------------
function waitUntilBlock(message, block, addBlocks) {
  var b = parseInt(block) + parseInt(addBlocks) + parseInt(1);
  console.log("RESULT: Waiting until '" + message + "' #" + block + "+" + addBlocks + "=#" + b + " currentBlock=" + eth.blockNumber);
  while (eth.blockNumber <= b) {
  }
  console.log("RESULT: Waited until '" + message + "' #" + block + "+" + addBlocks + "=#" + b + " currentBlock=" + eth.blockNumber);
  console.log("RESULT: ");
}


//-----------------------------------------------------------------------------
// Token Contract A
//-----------------------------------------------------------------------------
var tokenFromBlock = [0, 0, 0, 0];
function printTokenContractDetails(j) {
  if (tokenFromBlock[j] == 0) {
    tokenFromBlock[j] = baseBlock;
  }
  console.log("RESULT: token" + j + "ContractAddress=" + getShortAddressName(_tokenContractAddresses[j]));
  if (_tokenContractAddresses[j] != null) {
    var contract = _tokens[j];
    var decimals = _decimals[j];
    console.log("RESULT: token" + j + ".owner/new=" + getShortAddressName(contract.owner()) + "/" + getShortAddressName(contract.newOwner()));
    console.log("RESULT: token" + j + ".details='" + contract.symbol() + "' '" + contract.name() + "' " + decimals + " dp");
    console.log("RESULT: token" + j + ".totalSupply=" + contract.totalSupply().shift(-decimals));

    var latestBlock = eth.blockNumber;
    var i;

    var ownershipTransferredEvents = contract.OwnershipTransferred({}, { fromBlock: tokenFromBlock[j], toBlock: latestBlock });
    i = 0;
    ownershipTransferredEvents.watch(function (error, result) {
      console.log("RESULT: token" + j + ".OwnershipTransferred " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    ownershipTransferredEvents.stopWatching();

    var approvalEvents = contract.Approval({}, { fromBlock: tokenFromBlock[j], toBlock: latestBlock });
    i = 0;
    approvalEvents.watch(function (error, result) {
      // console.log("RESULT: token" + j + ".Approval " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result));
      console.log("RESULT: token" + j + ".Approval " + i++ + " #" + result.blockNumber +
        " tokenOwner=" + getShortAddressName(result.args.tokenOwner) +
        " spender=" + getShortAddressName(result.args.spender) + " tokens=" + result.args.tokens.shift(-decimals));
    });
    approvalEvents.stopWatching();

    var transferEvents = contract.Transfer({}, { fromBlock: tokenFromBlock[j], toBlock: latestBlock });
    i = 0;
    transferEvents.watch(function (error, result) {
      // console.log("RESULT: token" + j + ".Transfer " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result));
      console.log("RESULT: token" + j + ".Transfer " + i++ + " #" + result.blockNumber +
        " from=" + getShortAddressName(result.args.from) +
        " to=" + getShortAddressName(result.args.to) + " tokens=" + result.args.tokens.shift(-decimals));
    });
    transferEvents.stopWatching();

    tokenFromBlock[j] = latestBlock + 1;
  }
}


// -----------------------------------------------------------------------------
// DexOneExchange Contract
// -----------------------------------------------------------------------------
var dexOneExchangeContractAddress = null;
var dexOneExchangeContractAbi = null;
function addDexOneExchangeContractAddressAndAbi(address, abi) {
  dexOneExchangeContractAddress = address;
  dexOneExchangeContractAbi = abi;
}
function formatOrder(orderType, maker, baseTokenAddress, quoteTokenAddress, price, expiry, baseTokens, baseTokensFilled) {
  var makerString = getShortAddressName(maker);
  var baseToken = getAddressSymbol(baseTokenAddress);
  var quoteToken = getAddressSymbol(quoteTokenAddress);
  var minutes = (expiry - new Date() / 1000) / 60;
  return makerString + " " + (orderType == 0 ? "Buy" : "Sell") +
    " [filled " + baseTokensFilled.shift(-18) + " of] " + baseTokens.shift(-18) + " " +
    baseToken + " @ " + price.shift(-18) + " " +
    baseToken + "/" + quoteToken + " +" + minutes.toFixed(2) + "s";
}
var pairs = [];
function formatOrderEvent(orderType, maker, baseTokenAddress, quoteTokenAddress, price, expiry, baseTokens) {
  var makerString = getShortAddressName(maker);
  var baseToken = getAddressSymbol(baseTokenAddress);
  var quoteToken = getAddressSymbol(quoteTokenAddress);
  var minutes = (expiry - new Date() / 1000) / 60;
  return makerString + " " + (orderType == 0 ? "Buy" : "Sell") + " " + baseTokens.shift(-18) + " " +
    baseToken + " @ " + price.shift(-18) + " " +
    baseToken + "/" + quoteToken + " +" + minutes.toFixed(2) + "s";
}
var dexOneExchangeFromBlock = 0;
function printDexOneExchangeContractDetails() {
  if (dexOneExchangeFromBlock == 0) {
    dexOneExchangeFromBlock = baseBlock;
  }
  console.log("RESULT: dexOneExchange.address=" + getShortAddressName(dexOneExchangeContractAddress));
  if (dexOneExchangeContractAddress != null && dexOneExchangeContractAbi != null) {
    var contract = eth.contract(dexOneExchangeContractAbi).at(dexOneExchangeContractAddress);
    console.log("RESULT: dexOneExchange.owner/new=" + getShortAddressName(contract.owner()) + "/" + getShortAddressName(contract.newOwner()));
    console.log("RESULT: dexOneExchange.deploymentBlockNumber=" + contract.deploymentBlockNumber());
    console.log("RESULT: dexOneExchange.takerFeeInEthers=" + contract.takerFeeInEthers().shift(-18) + " ETH");
    console.log("RESULT: dexOneExchange.takerFeeInTokens=" + contract.takerFeeInTokens().shift(-16) + "%");
    console.log("RESULT: dexOneExchange.feeAccount=" + getShortAddressName(contract.feeAccount()));

    var i;
    var latestBlock = eth.blockNumber;

    var ownershipTransferredEvents = contract.OwnershipTransferred({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    ownershipTransferredEvents.watch(function (error, result) {
      console.log("RESULT: OwnershipTransferred " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    ownershipTransferredEvents.stopWatching();

    var tokenWhitelistUpdatedEvents = contract.TokenWhitelistUpdated({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    tokenWhitelistUpdatedEvents.watch(function (error, result) {
      console.log("RESULT: TokenWhitelistUpdated " + i++ + " #" + result.blockNumber + " token=" + getShortAddressName(result.args.token) +
        " status=" + result.args.status);
    });
    tokenWhitelistUpdatedEvents.stopWatching();

    var takerFeeInEthersUpdatedEvents = contract.TakerFeeInEthersUpdated({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    takerFeeInEthersUpdatedEvents.watch(function (error, result) {
      console.log("RESULT: TakerFeeInEthersUpdated " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    takerFeeInEthersUpdatedEvents.stopWatching();

    var takerFeeInTokensUpdatedEvents = contract.TakerFeeInTokensUpdated({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    takerFeeInTokensUpdatedEvents.watch(function (error, result) {
      console.log("RESULT: TakerFeeInTokensUpdated " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    takerFeeInTokensUpdatedEvents.stopWatching();

    var feeAccountUpdatedEvents = contract.FeeAccountUpdated({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    feeAccountUpdatedEvents.watch(function (error, result) {
      console.log("RESULT: FeeAccountUpdated " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    feeAccountUpdatedEvents.stopWatching();

    var tokenAddedEvents = contract.TokenAdded({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    tokenAddedEvents.watch(function (error, result) {
      console.log("RESULT: TokenAdded " + i++ + " #" + result.blockNumber + " token=" + getShortAddressName(result.args.token));
    });
    tokenAddedEvents.stopWatching();

    var accountAddedEvents = contract.AccountAdded({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    accountAddedEvents.watch(function (error, result) {
      console.log("RESULT: AccountAdded " + i++ + " #" + result.blockNumber + " account=" + getShortAddressName(result.args.account));
    });
    accountAddedEvents.stopWatching();

    var pairAddedEvents = contract.PairAdded({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    pairAddedEvents.watch(function (error, result) {
      pairs.push({pairKey: result.args.pairKey, baseToken: result.args.baseToken, quoteToken: result.args.quoteToken});
      console.log("RESULT: PairAdded " + i++ + " #" + result.blockNumber + " pairKey=" + result.args.pairKey +
        " baseToken=" + getShortAddressName(result.args.baseToken) + " quoteToken=" + getShortAddressName(result.args.quoteToken));
    });
    pairAddedEvents.stopWatching();

    var orderAddedEvents = contract.OrderAdded({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    orderAddedEvents.watch(function (error, result) {
      console.log("RESULT: OrderAdded " + i++ + " #" + result.blockNumber + " pairKey=" + result.args.pairKey + " key=" + result.args.key);
      console.log("RESULT:   " + formatOrderEvent(result.args.orderType, result.args.maker, result.args.baseToken,
        result.args.quoteToken, result.args.price, result.args.expiry, result.args.baseTokens));
    });
    orderAddedEvents.stopWatching();

    var orderRemovedEvents = contract.OrderRemoved({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    orderRemovedEvents.watch(function (error, result) {
      console.log("RESULT: OrderRemoved " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    orderRemovedEvents.stopWatching();

    var orderUpdatedEvents = contract.OrderUpdated({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    orderUpdatedEvents.watch(function (error, result) {
      console.log("RESULT: OrderUpdated " + i++ + " #" + result.blockNumber + " " + JSON.stringify(result.args));
    });
    orderUpdatedEvents.stopWatching();

    var tradeEvents = contract.Trade({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    tradeEvents.watch(function (error, result) {
      console.log("RESULT: Trade " + i++ + " #" + result.blockNumber + " key=" + result.args.key +
        " orderType=" + (result.args.orderType == 0 ? "Buy" : "Sell") +
        " taker=" + getShortAddressName(result.args.taker) + " maker=" + getShortAddressName(result.args.maker) +
        " amount=" + result.args.amount.shift(-18) +
        " baseToken=" + getAddressSymbol(result.args.baseToken) + " quoteToken=" + getAddressSymbol(result.args.quoteToken) +
        " baseTokens=" + result.args.baseTokens.shift(-18) + " quoteTokens=" + result.args.quoteTokens.shift(-18) +
        " feeBaseTokens=" + result.args.feeBaseTokens.shift(-18) + " feeQuoteTokens=" + result.args.feeQuoteTokens.shift(-18) +
        " baseTokensFilled=" + result.args.baseTokensFilled.shift(-18));
    });
    tradeEvents.stopWatching();

    var logUintEvents = contract.LogInfo({}, { fromBlock: dexOneExchangeFromBlock, toBlock: latestBlock });
    i = 0;
    logUintEvents.watch(function (error, result) {
      var noteStr = (result.args.note != "") ? " " + result.args.note : "";
      var addrStr = (result.args.addr != "0x0000000000000000000000000000000000000000") ? " " + getShortAddressName(result.args.addr) : "";
      var numberStr = (Math.abs(result.args.number) < 10000000000) ? result.args.number : result.args.number.shift(-18);
      var dataStr = result.args.data == "0x0000000000000000000000000000000000000000000000000000000000000000" ? "" : " " + result.args.data;
      console.log("RESULT: LogInfo " + i++ + " #" + result.blockNumber + " " + result.args.topic +
       " " + numberStr + dataStr + noteStr + addrStr);
    });
    logUintEvents.stopWatching();

    pairs.forEach(function(e) {
      console.log("RESULT: ----- Pair " + e.pairKey + " " + getAddressSymbol(e.baseToken) + "/" + getAddressSymbol(e.quoteToken) + " -----");
      for (var buySell = 0; buySell < 2; buySell++) {
        console.log("RESULT: --- " + (buySell == 0 ? "Buy" : "Sell") + " Orders ---");
        var orderPriceKey = 0;
        orderPriceKey = contract.getNextBestPrice(e.pairKey, buySell, orderPriceKey);
        while (orderPriceKey != 0) {
          var orderQueue = contract.getOrderQueue(e.pairKey, buySell, orderPriceKey);
          console.log("RESULT:   Price: " + orderPriceKey.shift(-18) + " head=" + orderQueue[1].substring(0, 18) + " tail=" + orderQueue[2].substring(0, 18));
          var orderKey = orderQueue[1];
          while (orderKey != 0) {
            var order = contract.getOrder(orderKey);
            // console.log("RESULT:       Order '" + orderKey + ": " + JSON.stringify(order));
            var minutes = (order[7] - new Date() / 1000) / 60;
            console.log("RESULT:     Order key=" + orderKey.substring(0, 18) + " prev=" + order[0].substring(0, 18) + " next=" + order[1].substring(0, 18) +
              (parseInt(order[2]) == 1 ? " Sell": " Buy") + " maker=" + getShortAddressName(order[3]) +
              " base=" + getAddressSymbol(order[4]) + " quote=" + getAddressSymbol(order[5]) + " price=" + order[6].shift(-18) +
              " expiry=" + minutes.toFixed(2) + "s baseTokens=" + order[8].shift(-18) + " baseTokensFilled=" + order[9].shift(-18));
            orderKey = order[1];
          }
          orderPriceKey = contract.getNextBestPrice(e.pairKey, buySell, orderPriceKey);
        }

        // var first = contract.first(e.pairKey, buySell);
        // console.log("RESULT: first=" + first);
        // var last = contract.last(e.pairKey, buySell);
        // console.log("RESULT: last=" + last);
        // var k = contract.first(e.pairKey, buySell);
        // while (k != 0) {
        //   console.log("RESULT:   " + k);
        //   k = contract.next(e.pairKey, buySell, k);
        // }
      }
    });

    dexOneExchangeFromBlock = latestBlock + 1;
  }
}
