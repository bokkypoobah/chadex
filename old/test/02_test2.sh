#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018. The MIT Licence.
# ----------------------------------------------------------------------------------------------

echo "Options: [full|takerSell|takerBuy|exchange]"

MODE=${1:-full}

source settings
echo "---------- Settings ----------" | tee $TEST2OUTPUT
cat ./settings | tee -a $TEST2OUTPUT
echo "" | tee -a $TEST2OUTPUT

CURRENTTIME=`date +%s`
CURRENTTIMES=`perl -le "print scalar localtime $CURRENTTIME"`
START_DATE=`echo "$CURRENTTIME+45" | bc`
START_DATE_S=`perl -le "print scalar localtime $START_DATE"`
END_DATE=`echo "$CURRENTTIME+60*2" | bc`
END_DATE_S=`perl -le "print scalar localtime $END_DATE"`

printf "CURRENTTIME = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST2OUTPUT
printf "START_DATE  = '$START_DATE' '$START_DATE_S'\n" | tee -a $TEST2OUTPUT
printf "END_DATE    = '$END_DATE' '$END_DATE_S'\n" | tee -a $TEST2OUTPUT

# Make copy of SOL file ---
# rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol --exclude=test/
rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol
# Copy modified contracts if any files exist
find ./modifiedContracts -type f -name \* -exec cp {} . \;

# --- Modify parameters ---
#`perl -pi -e "s/emit LogUint.*$//" $EXCHANGESOL`
# Does not work `perl -pi -e "print if(!/emit LogUint/);" $EXCHANGESOL`

DIFFS1=`diff -r -x '*.js' -x '*.json' -x '*.txt' -x 'testchain' -x '*.md' -x '*.sh' -x 'settings' -x 'modifiedContracts' $SOURCEDIR .`
echo "--- Differences $SOURCEDIR/*.sol *.sol ---" | tee -a $TEST2OUTPUT
echo "$DIFFS1" | tee -a $TEST2OUTPUT

solc_0.4.25 --version | tee -a $TEST2OUTPUT

# echo "var dexOneProxyOutput=`solc_0.4.24 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $PROXYSOL`;" > $PROXYJS
echo "var dexOneExchangeOutput=`solc_0.4.25 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $EXCHANGESOL`;" > $EXCHANGEJS
# echo "var dexWalletOutput=`solc_0.4.24 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $DEXWALLETSOL`;" > $DEXWALLETJS
echo "var mintableTokenOutput=`solc_0.4.25 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $MINTABLETOKENSOL`;" > $MINTABLETOKENJS

if [ "$MODE" = "compile" ]; then
  echo "Compiling only"
  exit 1;
fi

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST2OUTPUT
loadScript("$EXCHANGEJS");
loadScript("$MINTABLETOKENJS");
loadScript("lookups.js");
loadScript("functions.js");

var dexOneExchangeAbi = JSON.parse(dexOneExchangeOutput.contracts["$EXCHANGESOL:DexOneExchange"].abi);
var dexOneExchangeBin = "0x" + dexOneExchangeOutput.contracts["$EXCHANGESOL:DexOneExchange"].bin;
var mintableTokenAbi = JSON.parse(mintableTokenOutput.contracts["$MINTABLETOKENSOL:MintableToken"].abi);
var mintableTokenBin = "0x" + mintableTokenOutput.contracts["$MINTABLETOKENSOL:MintableToken"].bin;

// console.log("DATA: dexOneExchangeAbi=" + JSON.stringify(dexOneExchangeAbi));
// console.log("DATA: dexOneExchangeBin=" + JSON.stringify(dexOneExchangeBin));
// console.log("DATA: mintableTokenAbi=" + JSON.stringify(mintableTokenAbi));
// console.log("DATA: mintableTokenBin=" + JSON.stringify(mintableTokenBin));


unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");


var BUY = 0;
var SELL = 1;
var TAKERSELL = true;
var TAKERBUY = true;
var DUN = 0;
var DOO = 1;
var DRA = 2;
var WETH = 3;


// -----------------------------------------------------------------------------
var deployGroup1Message = "Deploy Group #1";
var numberOfTokens = $NUMBEROFTOKENS;
var _tokenSymbols = "$TOKENSYMBOLS".split(":");
var _tokenNames = "$TOKENNAMES".split(":");
var _tokenDecimals = "$TOKENDECIMALS".split(":");
var _tokenInitialSupplies = "$TOKENINITIALSUPPLIES".split(":");
var _tokenInitialDistributions = "$TOKENINITIALDISTRIBUTION".split(":");
// console.log("RESULT: _tokenSymbols = " + JSON.stringify(_tokenSymbols));
// console.log("RESULT: _tokenNames = " + JSON.stringify(_tokenNames));
// console.log("RESULT: _tokenDecimals = " + JSON.stringify(_tokenDecimals));
// console.log("RESULT: _tokenInitialSupplies = " + JSON.stringify(_tokenInitialSupplies));
// console.log("RESULT: _tokenInitialDistributions = " + JSON.stringify(_tokenInitialDistributions));
var i;

// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup1Message + " ----------");
var dexOneExchangeContract = web3.eth.contract(dexOneExchangeAbi);
var dexOneExchangeTx = null;
var dexOneExchangeAddress = null;
var dexOneExchange = dexOneExchangeContract.new(feeAccount, {from: deployer, data: dexOneExchangeBin, gas: 5000000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        dexOneExchangeTx = contract.transactionHash;
      } else {
        dexOneExchangeAddress = contract.address;
        addAccount(dexOneExchangeAddress, "DexOneExchange");
        addDexOneExchangeContractAddressAndAbi(dexOneExchangeAddress, dexOneExchangeAbi);
        console.log("DATA: var dexOneExchangeAddress=\"" + dexOneExchangeAddress + "\";");
        console.log("DATA: var dexOneExchangeAbi=" + JSON.stringify(dexOneExchangeAbi) + ";");
        console.log("DATA: var dexOneExchange=eth.contract(dexOneExchangeAbi).at(dexOneExchangeAddress);");
      }
    }
  }
);
var tokenTxs = [];
var tokenAddresses = [];
var tokens = [];
var tokenTxsToIndexMapping = {};
for (i = 0; i < numberOfTokens; i++) {
  var tokenContract = web3.eth.contract(mintableTokenAbi);
  tokens[i] = tokenContract.new(_tokenSymbols[i], _tokenNames[i], _tokenDecimals[i], deployer, _tokenInitialSupplies[i], {from: deployer, data: mintableTokenBin, gas: 2000000, gasPrice: defaultGasPrice},
    function(e, contract) {
      if (!e) {
        if (!contract.address) {
          // var i = tokenTxsToIndexMapping[contract.transactionHash];
          // tokenTxs[i] = contract.transactionHash;
        } else {
          var i = tokenTxsToIndexMapping[contract.transactionHash];
          tokenTxs[i] = contract.transactionHash;
          tokenAddresses[i] = contract.address;
          addAccount(tokenAddresses[i], "Token '" + tokens[i].symbol() + "' '" + tokens[i].name() + "'");
          addAddressSymbol(tokenAddresses[i], tokens[i].symbol());
          addTokenContractAddressAndAbi(i, tokenAddresses[i], mintableTokenAbi);
          console.log("DATA: var token" + i + "Address=\"" + tokenAddresses[i] + "\";");
          if (i == 0) {
            console.log("DATA: var tokenAbi=" + JSON.stringify(mintableTokenAbi) + ";");
          }
          console.log("DATA: var token" + i + "=eth.contract(tokenAbi).at(token" + i + "Address);");
        }
      }
    }
  );
  tokenTxsToIndexMapping[tokens[i].transactionHash] = i;
}
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(dexOneExchangeTx, deployGroup1Message + " - DexOneExchange");
for (i = 0; i < numberOfTokens; i++) {
  failIfTxStatusError(tokenTxs[i], deployGroup1Message + " - Token ''" + tokens[i].symbol() + "' '" + tokens[i].name() + "'");
}
printTxData("dexOneExchangeTx", dexOneExchangeTx);
for (i = 0; i < numberOfTokens; i++) {
  printTxData("tokenTx[" + i + "]", tokenTxs[i]);
}
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployGroup2Message = "Deploy Group #2";
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup2Message + " ----------");
var users = [user1, user2, user3, user4, user5, user6];
var deployGroup2_Txs = [];
users.forEach(function(u) {
  for (i = 0; i < numberOfTokens; i++) {
    var tx = tokens[i].mint(u, new BigNumber(_tokenInitialDistributions[i]).shift(_tokenDecimals[i]), {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
    deployGroup2_Txs.push(tx);
    tx = tokens[i].approve(dexOneExchangeAddress, new BigNumber(_tokenInitialDistributions[i]).shift(_tokenDecimals[i]), {from: u, gas: 2000000, gasPrice: defaultGasPrice});
    deployGroup2_Txs.push(tx);
  }
});
while (txpool.status.pending > 0) {
}
printBalances();
deployGroup2_Txs.forEach(function(t) {
  failIfTxStatusError(t, deployGroup2Message + " - Distribute tokens and approve spending - " + t);
});
deployGroup2_Txs.forEach(function(t) {
  printTxData("", t);
});
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var addOrders1Message = "Add Orders #1";
var buyPrice1 = new BigNumber(0.1).shift(18);
var buyPrice2 = new BigNumber(0.01).shift(18);
var sellPrice3 = new BigNumber(0.001).shift(18);
var buyAmount1 = new BigNumber("10000.00").shift(18);
var buyAmount2 = new BigNumber("1000.00").shift(18);
var sellAmount3 = new BigNumber("10000.00").shift(18);
var expiry = parseInt(new Date()/1000) + 60*60;
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + addOrders1Message + " ----------");
var addOrders1_1Tx = dexOneExchange.addOrder(BUY, tokenAddresses[DUN], tokenAddresses[DOO], buyPrice1, expiry, buyAmount1, {from: user1, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var addOrders1_2Tx = dexOneExchange.addOrder(BUY, tokenAddresses[DOO], tokenAddresses[WETH], buyPrice2, expiry, buyAmount2, {from: user2, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var addOrders1_3Tx = dexOneExchange.addOrder(SELL, tokenAddresses[DUN], tokenAddresses[WETH], sellPrice3, expiry, sellAmount3, {from: user3, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(addOrders1_1Tx, addOrders1Message + " - user1 addOrder(BUY, " + tokens[DUN].symbol() + ", " + tokens[DOO].symbol() + ", " + buyPrice1.shift(-18) + ", +1h, " + buyAmount.shift(-18) + ")");
failIfTxStatusError(addOrders1_2Tx, addOrders1Message + " - user2 addOrder(BUY, " + tokens[DOO].symbol() + ", " + tokens[WETH].symbol() + ", " + buyPrice2.shift(-18) + ", +1h, " + buyAmount.shift(-18) + ")");
failIfTxStatusError(addOrders1_3Tx, addOrders1Message + " - user3 addOrder(SELL, " + tokens[DUN].symbol() + ", " + tokens[WETH].symbol() + ", " + sellPrice3.shift(-18) + ", +1h, " + sellAmount.shift(-18) + ")");
printTxData("addOrders1_1Tx", addOrders1_1Tx);
printTxData("addOrders1_2Tx", addOrders1_2Tx);
printTxData("addOrders1_3Tx", addOrders1_3Tx);
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
console.log("RESULT: ");


// Maker B/S BaseTokens Base/Quote      Price Cpty QuoteTokens
// ----- --- ---------- ------------- ------- ---- -----------
// u1    b        10000 DUN/DOO   @ 0.1   u2        1000
// u2    b         1000 DOO/WETH    @ 0.01   u1          10
// u3    s        10000 DUN/WETH   @ 0.001   u1          10


if ("$MODE" == "full" || "$MODE" == "exchange") {
  // -----------------------------------------------------------------------------
  var exchange1Message = "Exchange #1";
  var keys = [dexOneExchange.ordersIndex(0), dexOneExchange.ordersIndex(1), dexOneExchange.ordersIndex(2)];
  console.log("RESULT: keys=" + JSON.stringify(keys));
  var baseTokens = [new BigNumber(10000).shift(18), new BigNumber(1000).shift(18), new BigNumber(10000).shift(18)];
  console.log("RESULT: baseTokens=" + JSON.stringify(baseTokens));
  var quoteTokens = [new BigNumber(1000).shift(18), new BigNumber(10).shift(18), new BigNumber(10).shift(18)];
  console.log("RESULT: quoteTokens=" + JSON.stringify(quoteTokens));
  var cpty = [user3, user3, user1];
  console.log("RESULT: cpty=" + JSON.stringify(cpty));
  var tokenAddresses = [tokenAddresses[DUN], tokenAddresses[DOO], tokenAddresses[WETH]];
  console.log("RESULT: tokenAddresses=" + JSON.stringify(tokenAddresses));
  // -----------------------------------------------------------------------------
  console.log("RESULT: ---------- " + exchange1Message + " ----------");
  var exchange1_1Tx = dexOneExchange.exchange(keys, baseTokens, quoteTokens, cpty, tokenAddresses, {from: deployer, gas: 2000000, gasPrice: defaultGasPrice});
  while (txpool.status.pending > 0) {
  }
  printBalances();
  failIfTxStatusError(exchange1_1Tx, exchange1Message + " - deployer dexOneExchange.exchange(...)");
  printTxData("exchange1_1Tx", exchange1_1Tx);
  console.log("RESULT: ");
  printDexOneExchangeContractDetails();
  console.log("RESULT: ");
  for (i = 0; i < numberOfTokens; i++) {
    printTokenContractDetails(i);
    console.log("RESULT: ");
  }
  console.log("RESULT: ");
}


EOF
grep "DATA: " $TEST2OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST2OUTPUT | sed "s/RESULT: //" > $TEST2RESULTS
cat $TEST2RESULTS
