#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Get testing account information
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019. The MIT Licence.
# ----------------------------------------------------------------------------------------------

echo "Options: [full|takerSell|takerBuy|exchange]"

MODE=${1:-view}

source settings
echo "---------- Settings ----------" | tee $TEST1OUTPUT
cat ./settings | tee -a $TEST1OUTPUT
echo "" | tee -a $TEST1OUTPUT
echo "MODE: $MODE" | tee -a $TEST1OUTPUT

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("lookups.js");
loadScript("functions.js");
loadScript("deploymentData.js");

unlockAccounts("", "dummy");

addAccount("$TOKEN1ADDRESS", "$TOKEN1CODE");
addAccount("$TOKEN2ADDRESS", "$TOKEN2CODE");
addAccount("$TEST1ACCOUNT", "Test11111");
addAccount("$TEST2ACCOUNT", "Test22222");
addAccount("$DEXZADDRESS", "Dexz");

addAddressSymbol("$TOKEN1ADDRESS", "$TOKEN1CODE");
addTokenContractAddressAndAbi(0, "$TOKEN1ADDRESS", weenusAbi);
addAddressSymbol("$TOKEN2ADDRESS", "$TOKEN2CODE");
addTokenContractAddressAndAbi(1, "$TOKEN2ADDRESS", xeenusAbi);
addDexOneExchangeContractAddressAndAbi(dexzAddress, dexzAbi);

printBalances();
console.log("RESULT: ");
printDexOneExchangeContractDetails($BASEBLOCK);
console.log("RESULT: ");


// Note that the BUY and SELL flags are used as indices
var ORDERTYPE_BUY = 0x00;
var ORDERTYPE_SELL = 0x01;
var ORDERFLAG_BUYSELL_MASK = 0x01;
// BK Default is to fill as much as possible
var ORDERFLAG_FILL = 0x00;
var ORDERFLAG_FILLALL_OR_REVERT = 0x10;
var ORDERFLAG_FILL_AND_ADD_ORDER = 0x20;


if ("$MODE" == "addorder") {

  var orderFlag = ORDERTYPE_BUY | ORDERFLAG_FILL_AND_ADD_ORDER;
  console.log("RESULT: orderFlag: " + orderFlag);
  var buyAmount = new BigNumber(1).shift(18);
  var buyPrice = new BigNumber(1).shift(18);
  var expiry = parseInt(new Date() / 1000) + 600;
  var uiFeeAccount = "$UIFEEACCOUNT";
  var tradeData = dexz.trade.getData(orderFlag, weenus.address, xeenus.address, buyPrice, expiry, buyAmount, uiFeeAccount, {from: "$TEST1ACCOUNT", gas: 3000000, gasPrice: web3.toWei(5, "gwei")});
  console.log("RESULT: tradeData[Buy 1500 WEENUS @ WEENUS/XEENUS]='" + tradeData + "'");
  var approveAndCall1 = zeenus.approveAndCall(dexzAddress, buyAmount, tradeData, {from: "$TEST1ACCOUNT", gas: 2000000, gas: 1000000, gasPrice: web3.toWei(5, "gwei")});
  while (eth.getTransactionReceipt(approveAndCall1) == null) {
  }

  printBalances();
  console.log("RESULT: ");
  printDexOneExchangeContractDetails($BASEBLOCK);
  console.log("RESULT: ");
}


exit;

var approveAndCallMessage = "ApproveAndCall #1";
var buyAmount = new BigNumber(1500).shift(18);
// var data = "0xaabbccdd" + "1122334455667788990011223344556677889900112233445566778899001122" + \
//   "1222334455667788990011223344556677889900112233445566778899001122" + "1322334455667788990011223344556677889900112233445566778899001122" + \
//   "1422334455667788990011223344556677889900112233445566778899001122" + "1522334455667788990011223344556677889900112233445566778899001122" + \
//   "1622334455667788990011223344556677889900112233445566778899001122" + "1722334455667788990011223344556677889900112233445566778899001122";
var tradeData = dexz.trade.getData(BUY, tokenAddresses[ABC], tokenAddresses[WETH], buyPrice2, expiry, buyAmount, uiFeeAccount, {from: user5, gas: 3000000, gasPrice: defaultGasPrice});
console.log("RESULT: tradeData[Buy 1500 ABC/WETH]='" + tradeData + "'");
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + approveAndCallMessage + " ----------");
var approveAndCall1_1Tx = tokens[ABC].approveAndCall(dexzAddress, buyAmount, tradeData, {from: user5, gas: 2000000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printBalances();
failIfTxStatusError(approveAndCall1_1Tx, approveAndCallMessage + " - user5 " + tokens[ABC].symbol() + ".approveAndCall(dexz, " + buyAmount.shift(-18) + ", '" + tradeData + "')");
printTxData("approveAndCall1_1Tx", approveAndCall1_1Tx);
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");
for (i = 0; i < numberOfTokens; i++) {
  printTokenContractDetails(i);
  console.log("RESULT: ");
}
console.log("RESULT: ");


EOF
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
