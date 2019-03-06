#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Get testing account information
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019. The MIT Licence.
# ----------------------------------------------------------------------------------------------

echo "Options: [full|takerSell|takerBuy|exchange]"

MODE=${1:-full}

source settings
echo "---------- Settings ----------" | tee $TEST1OUTPUT
cat ./settings | tee -a $TEST1OUTPUT
echo "" | tee -a $TEST1OUTPUT

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("lookups.js");
loadScript("functions.js");
loadScript("deploymentData.js");

unlockAccounts("", "dummy");

addAccount("$TOKEN1ADDRESS", "$TOKEN1CODE");
addAccount("$TOKEN2ADDRESS", "$TOKEN2CODE");
addAccount("$TEST1ACCOUNT", "Test11111");
addAccount("$TEST2ACCOUNT", "Test2222");

addAddressSymbol("$TOKEN1ADDRESS", "$TOKEN1CODE");
addTokenContractAddressAndAbi(0, "$TOKEN1ADDRESS", weenusAbi);
addAddressSymbol("$TOKEN2ADDRESS", "$TOKEN2CODE");
addTokenContractAddressAndAbi(1, "$TOKEN2ADDRESS", xeenusAbi);

printBalances();



EOF
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
