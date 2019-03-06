#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Deploy the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2019. The MIT Licence.
# ----------------------------------------------------------------------------------------------

echo "Options: [full|takerSell|takerBuy|exchange]"

MODE=${1:-full}

source settings
echo "---------- Settings ----------" | tee $TEST1OUTPUT
cat ./settings | tee -a $TEST1OUTPUT
echo "" | tee -a $TEST1OUTPUT

CURRENTTIME=`date +%s`
CURRENTTIMES=`perl -le "print scalar localtime $CURRENTTIME"`
START_DATE=`echo "$CURRENTTIME+45" | bc`
START_DATE_S=`perl -le "print scalar localtime $START_DATE"`
END_DATE=`echo "$CURRENTTIME+60*2" | bc`
END_DATE_S=`perl -le "print scalar localtime $END_DATE"`

printf "CURRENTTIME = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST1OUTPUT
printf "START_DATE  = '$START_DATE' '$START_DATE_S'\n" | tee -a $TEST1OUTPUT
printf "END_DATE    = '$END_DATE' '$END_DATE_S'\n" | tee -a $TEST1OUTPUT

# Make copy of SOL file ---
# rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol --exclude=test/
# FIXUP - to add modification capability
# rsync -rp $SOURCEDIR/* . --exclude=Multisig.sol
# Copy modified contracts if any files exist
# FIXUP - to add modification capability
# find ./modifiedContracts -type f -name \* -exec cp {} . \;

# --- Modify parameters ---
#`perl -pi -e "s/emit LogUint.*$//" $EXCHANGESOL`
# Does not work `perl -pi -e "print if(!/emit LogUint/);" $EXCHANGESOL`

# FIXUP - to add modification capability
# DIFFS1=`diff -r -x '*.js' -x '*.json' -x '*.txt' -x 'testchain' -x '*.md' -x '*.sh' -x 'settings' -x 'modifiedContracts' -x 'flattened' $SOURCEDIR .`
# echo "--- Differences $SOURCEDIR/*.sol *.sol ---" | tee -a $TEST1OUTPUT
# echo "$DIFFS1" | tee -a $TEST1OUTPUT

solc_0.5.4 --version | tee -a $TEST1OUTPUT

../scripts/solidityFlattener.pl --contractsdir=../contracts --mainsol=$EXCHANGESOL --outputsol=$EXCHANGEFLATTENED --verbose | tee -a $TEST1OUTPUT

echo "var dexzOutput=`solc_0.5.4 --allow-paths . --optimize --pretty-json --combined-json abi,bin,interface $EXCHANGEFLATTENED`;" > $EXCHANGEJS

if [ "$MODE" = "compile" ]; then
  echo "Compiling only"
  exit 1;
fi

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("$EXCHANGEJS");
loadScript("lookups.js");
loadScript("functions.js");

var rbtLibAbi = JSON.parse(dexzOutput.contracts["$EXCHANGEFLATTENED:BokkyPooBahsRedBlackTreeLibrary"].abi);
var rbtLibBin = "0x" + dexzOutput.contracts["$EXCHANGEFLATTENED:BokkyPooBahsRedBlackTreeLibrary"].bin;
var dexzAbi = JSON.parse(dexzOutput.contracts["$EXCHANGEFLATTENED:Dexz"].abi);
var dexzBin = "0x" + dexzOutput.contracts["$EXCHANGEFLATTENED:Dexz"].bin;

// console.log("DATA: rbtLibAbi=" + JSON.stringify(rbtLibAbi));
// console.log("DATA: rbtLibBin=" + JSON.stringify(rbtLibBin));
// console.log("DATA: dexzAbi=" + JSON.stringify(dexzAbi));
// console.log("DATA: dexzBin=" + JSON.stringify(dexzBin));


unlockAccounts("$PASSWORD", "$DEPLOYMENT");
printBalances();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployGroup1Message = "Deploy Group #1";
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup1Message + " ----------");
var rbtLibContract = web3.eth.contract(rbtLibAbi);
var rbtLibTx = null;
var rbtLibAddress = null;
console.log("RESULT: DEPLOYMENTACCOUNT: $DEPLOYMENTACCOUNT");
console.log("RESULT: " + defaultGasPrice);
console.log("RESULT: " + JSON.stringify(rbtLibContract));
var rbtLib = rbtLibContract.new({from: "$DEPLOYMENTACCOUNT", data: rbtLibBin, gas: 3000000, gasPrice: web3.toWei("$GASPRICEINGWEI", "gwei")},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        rbtLibTx = contract.transactionHash;
      } else {
        rbtLibAddress = contract.address;
        addAccount(rbtLibAddress, "RBTLib");
        console.log("DATA: var rbtLibAddress=\"" + rbtLibAddress + "\";");
        console.log("DATA: var rbtLibAbi=" + JSON.stringify(rbtLibAbi) + ";");
        console.log("DATA: var rbtLib=eth.contract(rbtLibAbi).at(rbtLibAddress);");
      }
    }
  }
);
// while (txpool.status.pending > 0) {
// }
console.log("RESULT: WAIT for rbtLibTx: " + rbtLibTx);
while (eth.getTransactionReceipt(rbtLibTx) == null) {
}
console.log("RESULT: WAITED for rbtLibTx: " + rbtLibTx);
printBalances();
failIfTxStatusError(rbtLibTx, deployGroup1Message + " - RBTLib");
printTxData("rbtLibTx", rbtLibTx);
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployGroup2Message = "Deploy Group #2";
// -----------------------------------------------------------------------------
console.log("RESULT: ---------- " + deployGroup2Message + " ----------");
var rbtLibName = "$EXCHANGEFLATTENED:BokkyPooBahsRedBlackTreeLibrary";
var rbtLibSearchHash = "__\$" + web3.sha3(rbtLibName).substring(2, 36) + "\$__";
console.log("RESULT: rbtLibSearchHash='" + rbtLibSearchHash + "'");
console.log("RESULT: old='" + dexzBin + "'");
var newDexzBin = dexzBin.split(rbtLibSearchHash).join(rbtLibAddress.substring(2, 42));
console.log("RESULT: new='" + newDexzBin + "'");
var dexzContract = web3.eth.contract(dexzAbi);
var dexzTx = null;
var dexzAddress = null;
var dexz = dexzContract.new(feeAccount, {from: "$DEPLOYMENTACCOUNT", data: newDexzBin, gas: 6400000, gasPrice: web3.toWei("$GASPRICEINGWEI", "gwei")},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        dexzTx = contract.transactionHash;
      } else {
        dexzAddress = contract.address;
        addAccount(dexzAddress, "DexOneExchange");
        addDexOneExchangeContractAddressAndAbi(dexzAddress, dexzAbi);
        console.log("DATA: var dexzAddress=\"" + dexzAddress + "\";");
        console.log("DATA: var dexzAbi=" + JSON.stringify(dexzAbi) + ";");
        console.log("DATA: var dexz=eth.contract(dexzAbi).at(dexzAddress);");
      }
    }
  }
);
console.log("RESULT: WAIT for dexzTx: " + dexzTx);
while (eth.getTransactionReceipt(dexzTx) == null) {
}
console.log("RESULT: WAITED for dexzTx: " + dexzTx);
printBalances();
failIfTxStatusError(dexzTx, deployGroup2Message + " - DexOneExchange");
printTxData("dexzTx", dexzTx);
console.log("RESULT: ");
printDexOneExchangeContractDetails();
console.log("RESULT: ");


EOF
grep "DATA: " $TEST1OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
egrep -e "dexzTx.*gasUsed|ordersTx.*gasUsed" $TEST1RESULTS
