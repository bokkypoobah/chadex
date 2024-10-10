const { ZERO_ADDRESS, PAIRKEY_NULL, ORDERKEY_SENTINEL, BUYORSELL, ANYORALL, BUYORSELLSTRING, ANYORALLSTRING, Data, generateRange } = require('./helpers/common');
// const { singletons, expectRevert } = require("@openzeppelin/test-helpers");
const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const util = require('util');

const BuySell = {
  Buy: 0,
  Sell: 1,
};

const Action = {
  FillAny: 0,
  FillAllOrNothing: 1,
  FillAnyAndAddOrder: 2,
  RemoveOrder: 3,
  UpdateExpiryAndTokens: 4,
}

let data;

describe("Chadex", function () {
  const DETAILS = 1;

  beforeEach(async function () {
    console.log();
    console.log("      beforeEach");
    const Token  = await ethers.getContractFactory("Token");
    const Weth  = await ethers.getContractFactory("WETH9");
    const Chadex  = await ethers.getContractFactory("Chadex");
    data = new Data();
    await data.init();

    console.log("        --- Setup Tokens and Chadex Contracts. Assuming gasPrice: " + ethers.formatUnits(data.gasPrice, "gwei") + " gwei, ethUsd: " + ethers.formatUnits(data.ethUsd, 18) + " ---");

    const token0 = await Token.deploy("TOK0", "Token0", 18, ethers.parseUnits("400", 18));
    // await token0.deployed();
    await data.setToken0(token0);
    // const token0Receipt = await data.token0.deployTransaction.wait();
    // if (DETAILS > 0) {
    //   await data.printEvents("Deployed Token0", token0Receipt);
    // }
    console.log("        Token0 deployed: " + token0.target);

    const token1 = await Token.deploy("TOK1", "Token1", 18, ethers.parseUnits("400", 18));
    // await token1.deployed();
    await data.setToken1(token1);
    // const token1Receipt = await data.token1.deployTransaction.wait();
    // if (DETAILS > 0) {
    //   await data.printEvents("Deployed Token1", token1Receipt);
    // }
    console.log("        Token1 deployed: " + token1.target);

    const weth = await Weth.deploy();
    // await weth.deployed();
    await data.setWeth(weth);
    // const wethReceipt = await data.weth.deployTransaction.wait();
    // if (DETAILS > 0) {
    //   await data.printEvents("Deployed WETH", wethReceipt);
    // }
    console.log("        WETH deployed: " + weth.target);

    const chadex = await Chadex.deploy({ gasLimit: 6_000_000 });
    // await chadex.deployed();
    await data.setChadex(chadex);
    // const chadexReceipt = await data.chadex.deployTransaction.wait();
    // if (DETAILS > 0) {
    //   await data.printEvents("Deployed Chadex", chadexReceipt);
    // }
    console.log("        Chadex deployed: " + chadex.target);

    const setup1 = [];
    const amount0 = ethers.parseUnits("100", data.decimals0);
    setup1.push(token0.transfer(data.user0, amount0));
    setup1.push(token0.transfer(data.user1, amount0));
    setup1.push(token0.transfer(data.user2, amount0));
    setup1.push(token0.transfer(data.user3, amount0));
    const [transferToken00Tx, transferToken01Tx, transferToken02Tx, transferToken03Tx] = await Promise.all(setup1);
    if (DETAILS > 0) {
      [transferToken00Tx, transferToken01Tx, transferToken02Tx, transferToken03Tx].forEach( async function (a) {
        await data.printEvents("Transfer Token0", await a.wait());
      });
    }
    const setup2 = [];
    const amount1 = ethers.parseUnits("100", data.decimals1);
    setup2.push(token1.transfer(data.user0, amount1));
    setup2.push(token1.transfer(data.user1, amount1));
    setup2.push(token1.transfer(data.user2, amount1));
    setup2.push(token1.transfer(data.user3, amount1));
    const [transferToken10Tx, transferToken11Tx, transferToken12Tx, transferToken13Tx] = await Promise.all(setup2);
    if (DETAILS > 0) {
      [transferToken10Tx, transferToken11Tx, transferToken12Tx, transferToken13Tx].forEach( async function (a) {
        await data.printEvents("Transfer Token1", await a.wait());
      });
    }
    console.log("        Tokens transferred");

    const amountWeth = ethers.parseUnits("100", data.decimalsWeth);
    const weth0Tx = await data.user0Signer.sendTransaction({ to: data.weth.target, value: amountWeth });
    const weth1Tx = await data.user1Signer.sendTransaction({ to: data.weth.target, value: amountWeth });
    const weth2Tx = await data.user2Signer.sendTransaction({ to: data.weth.target, value: amountWeth });
    const weth3Tx = await data.user3Signer.sendTransaction({ to: data.weth.target, value: amountWeth });
    await data.printEvents("Send weth" , await weth0Tx.wait());
    await data.printEvents("Send weth" , await weth1Tx.wait());
    await data.printEvents("Send weth" , await weth2Tx.wait());
    await data.printEvents("Send weth" , await weth3Tx.wait());

    const approveAmount0 = ethers.parseUnits("10", data.decimals0);
    const approveAmount1 = ethers.parseUnits("10", data.decimals1);
    const approveAmountWeth = ethers.parseUnits("2.69", data.decimalsWeth);

    const approve00Tx = await data.token0.connect(data.user0Signer).approve(data.chadex.target, approveAmount0);
    const approve10Tx = await data.token1.connect(data.user0Signer).approve(data.chadex.target, approveAmount1);
    const approve20Tx = await data.weth.connect(data.user0Signer).approve(data.chadex.target, approveAmountWeth);

    const approve01Tx = await data.token0.connect(data.user1Signer).approve(data.chadex.target, approveAmount0);
    const approve11Tx = await data.token1.connect(data.user1Signer).approve(data.chadex.target, approveAmount1);
    const approve21Tx = await data.weth.connect(data.user1Signer).approve(data.chadex.target, approveAmountWeth);

    const approve02Tx = await data.token0.connect(data.user2Signer).approve(data.chadex.target, approveAmount0);
    const approve12Tx = await data.token1.connect(data.user2Signer).approve(data.chadex.target, approveAmount1);
    const approve22Tx = await data.weth.connect(data.user2Signer).approve(data.chadex.target, approveAmountWeth);

    const approve03Tx = await data.token0.connect(data.user3Signer).approve(data.chadex.target, approveAmount0);
    const approve13Tx = await data.token1.connect(data.user3Signer).approve(data.chadex.target, approveAmount1);
    const approve23Tx = await data.weth.connect(data.user3Signer).approve(data.chadex.target, approveAmountWeth);

    await data.printEvents("user0->token0.approve(chadex, " + ethers.formatUnits(approveAmount0, data.decimals0) + ")", await approve00Tx.wait());
    await data.printEvents("user0->token1.approve(chadex, " + ethers.formatUnits(approveAmount1, data.decimals1) + ")", await approve10Tx.wait());
    await data.printEvents("user0->weth.approve(chadex, " + ethers.formatUnits(approveAmountWeth, data.decimalsWeth) + ")", await approve20Tx.wait());
    await data.printEvents("user1->token0.approve(chadex, " + ethers.formatUnits(approveAmount0, data.decimals0) + ")", await approve01Tx.wait());
    await data.printEvents("user1->token1.approve(chadex, " + ethers.formatUnits(approveAmount1, data.decimals1) + ")", await approve11Tx.wait());
    await data.printEvents("user1->weth.approve(chadex, " + ethers.formatUnits(approveAmountWeth, data.decimalsWeth) + ")", await approve21Tx.wait());

    await data.printEvents("user2->token0.approve(chadex, " + ethers.formatUnits(approveAmount0, data.decimals0) + ")", await approve02Tx.wait());
    await data.printEvents("user2->token1.approve(chadex, " + ethers.formatUnits(approveAmount1, data.decimals1) + ")", await approve12Tx.wait());
    await data.printEvents("user2->weth.approve(chadex, " + ethers.formatUnits(approveAmountWeth, data.decimalsWeth) + ")", await approve22Tx.wait());

    await data.printEvents("user3->token0.approve(chadex, " + ethers.formatUnits(approveAmount0, data.decimals0) + ")", await approve03Tx.wait());
    await data.printEvents("user3->token1.approve(chadex, " + ethers.formatUnits(approveAmount1, data.decimals1) + ")", await approve13Tx.wait());
    await data.printEvents("user3->weth.approve(chadex, " + ethers.formatUnits(approveAmountWeth, data.decimalsWeth) + ")", await approve23Tx.wait());

    //   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");

    // await data.printState("Setup Completed. Chadex bytecode ~" + JSON.stringify(data.chadex.deployTransaction.data.length/2, null, 2));
  });

  it("00. Test 00", async function () {
    console.log("      00. Test 00 - Happy Path - Specified Set");

    // Add Orders
    const price1 = "0.6901";
    const price2 = "0.6902";
    const price3 = "0.6903";
    const price5 = "0.6905";
    const price6 = "0.6906";
    const price7 = "0.6907";
    const expired = parseInt(new Date()/1000) - 60*60;
    const expiry = parseInt(new Date()/1000) + 60*60;
    const baseTokens1 = ethers.parseUnits("1", data.decimals0);
    const baseTokens2 = ethers.parseUnits("2", data.decimals0);
    const baseTokens3 = ethers.parseUnits("3", data.decimals0);
    const baseTokens4 = ethers.parseUnits("6.9", data.decimals0);
    const baseTokens5 = ethers.parseUnits("69", data.decimals0);

    const actionsA = [
      { action: Action.FillAnyAndAddOrder, buySell: BuySell.Buy, tokenz: [data.token0.target, data.weth.target], price: ethers.parseUnits(price1, 9).toString(), targetPrice: ethers.parseUnits(price1, 9).toString(), expiry: expiry, tokens: baseTokens1.toString(), skipCheck: false },
      { action: Action.FillAnyAndAddOrder, buySell: BuySell.Buy, tokenz: [data.token0.target, data.weth.target], price: ethers.parseUnits(price2, 9).toString(), targetPrice: ethers.parseUnits(price2, 9).toString(), expiry: expiry, tokens: baseTokens2.toString(), skipCheck: false },
      { action: Action.FillAnyAndAddOrder, buySell: BuySell.Buy, tokenz: [data.token0.target, data.weth.target], price: ethers.parseUnits(price3, 9).toString(), targetPrice: ethers.parseUnits(price3, 9).toString(), expiry: expiry, tokens: baseTokens3.toString(), skipCheck: false },
    ];
    console.log("        Executing: " + JSON.stringify(actionsA, null, 2));

    const execute0aTx = await data.chadex.connect(data.user0Signer).execute(actionsA);
    await data.printEvents("user0->chadex.execute(actionsA)", await execute0aTx.wait());

    return;

    const execute1aTx = await data.chadex.connect(data.user1Signer).execute(actionsA);
    await data.printEvents("user1->chadex.execute(actionsA)", await execute1aTx.wait());

    const execute1bTx = await data.chadex.connect(data.user2Signer).execute(actionsA);
    await data.printEvents("user2->chadex.execute(actionsA)", await execute1bTx.wait());

    await data.printState("After Adding Orders");

    const targetPrice1 = "0.6901";
    const baseTokensB1 = ethers.parseUnits("10", data.decimals0);
    const actionsB1 = [
      { action: Action.FillAnyAndAddOrder, buySell: BuySell.Sell, tokenz: [data.token0.target, data.weth.target], price: ethers.parseUnits(price1, 9).toString(), targetPrice: ethers.parseUnits(targetPrice1, 9).toString(), expiry: expiry, tokens: baseTokensB1.toString(), skipCheck: false },
      // { action: Action.FillAnyAndAddOrder, buySell: BuySell.Sell, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price3, 9).toString(), targetPrice: ethers.parseUnits(targetPrice1, 9).toString(), expiry: expiry, tokens: baseTokensB1.toString() },
    ];
    console.log("        Executing: " + JSON.stringify(actionsB1, null, 2));
    const executeB1Tx = await data.chadex.connect(data.user3Signer).execute(actionsB1);
    await data.printEvents("user3->chadex.execute(actions)", await executeB1Tx.wait());

    // const baseTokensB2 = ethers.parseUnits("6.9", data.decimals0);
    // const actionsB2 = [
    //   { action: Action.FillAnyAndAddOrder, buySell: BuySell.Sell, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price1, 9).toString(), targetPrice: ethers.parseUnits(targetPrice1, 9).toString(), expiry: expiry, tokens: baseTokensB2.toString() },
    //   { action: Action.FillAnyAndAddOrder, buySell: BuySell.Sell, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price2, 9).toString(), targetPrice: ethers.parseUnits(targetPrice1, 9).toString(), expiry: expiry, tokens: baseTokensB2.toString() },
    // ];
    // console.log("        Executing: " + JSON.stringify(actionsB2, null, 2));
    // const executeB2Tx = await data.chadex.connect(data.user3Signer).execute(actionsB2);
    // await data.printEvents("user3->chadex.execute(actions)", await executeB2Tx.wait());

    await data.printState("After Executing Against Orders");

    // const sendMessageTx = await data.chadex.connect(data.user3Signer).sendMessage(ZERO_ADDRESS, PAIRKEY_NULL, ORDERKEY_SENTINEL, "Hello", "World!");
    // await data.printEvents("user3->chadex.sendMessage(blah)", await sendMessageTx.wait());

    // function sendMessage(address to, bytes32 pairKey, bytes32 orderKey, string calldata topic, string calldata text) public {

    const owners = [data.user0];
    const tokens = [data.token0.target];
    const tokenBalanceAndAllowance = await data.chadex.getTokenBalanceAndAllowance(owners, tokens);
    console.log("tokenBalanceAndAllowance: " + JSON.stringify(tokenBalanceAndAllowance, null, 2));

    // const tradeEvents = await data.chadex.getTradeEvents(10, 0);
    // console.log("tradeEvents: " + JSON.stringify(tradeEvents, null, 2));

    // const pairs = await data.chadex.getPairs(2, 0);
    // console.log("pairs: " + JSON.stringify(pairs, null, 2));
    // struct PairTokenResult {
    //     Token token;
    //     string symbol;
    //     string name;
    //     uint8 decimals;
    // }
    // struct PairResult {
    //     PairKey pairKey;
    //     PairTokenResult base;
    //     PairTokenResult quote;
    //     Factor multiplier;
    //     Factor divisor;
    //     BestOrderResult bestBuyOrderResult;
    //     BestOrderResult bestSellOrderResult;
    // }



    // const baseTokensB1 = ethers.parseUnits("0.31", data.decimals0);
    // const actionsB1 = [
    //   { action: Action.FillAnyAndAddOrder, buySell: BuySell.Sell, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price1, 9).toString(), targetPrice: ethers.parseUnits(price1, 9).toString(), expiry: expiry, tokens: baseTokensB1.toString() },
    // ];
    // console.log("        Executing: " + JSON.stringify(actionsB1, null, 2));
    // const executeB1Tx = await data.chadex.connect(data.user2Signer).execute(actionsB1);
    // await data.printEvents("user2->chadex.execute(actions)", await executeB1Tx.wait());
    // await data.printState("After Executing Against Orders");

    // const baseTokensC = ethers.parseUnits("-1", data.decimals0);
    // const actionsC = [
    //   { action: Action.RemoveOrder, buySell: BuySell.Buy, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price3, 9).toString(), targetPrice: ethers.parseUnits(price1, 9).toString(), expiry: expiry, tokens: baseTokensC.toString() },
    // ];
    // console.log("        Executing: " + JSON.stringify(actionsC, null, 2));
    // const executeCTx = await data.chadex.connect(data.user2Signer).execute(actionsC);
    // await data.printEvents("user2->chadex.execute(actions)", await executeCTx.wait());
    // await data.printState("After Executing Against Orders");

    // const newExpiry = parseInt(new Date()/1000) + 24*60*60;
    // const baseTokensD = ethers.parseUnits("-0.3", data.decimals0);
    // const actionsD = [
    //   { action: Action.UpdateExpiryAndTokens, buySell: BuySell.Buy, base: data.token0.target, quote: data.weth.target, price: ethers.parseUnits(price1, 9).toString(), targetPrice: ethers.parseUnits(price1, 9).toString(), expiry: newExpiry, tokens: baseTokensD.toString() },
    // ];
    // console.log("        Executing: " + JSON.stringify(actionsD, null, 2));
    // const executeDTx = await data.chadex.connect(data.user0Signer).execute(actionsD);
    // await data.printEvents("user0->chadex.execute(actions)", await executeDTx.wait());
    // await data.printState("After Executing Against Orders");


    // // Execute against orders
    // const sellBaseTokens = ethers.parseUnits("1", data.decimals0);
    // const trade4Tx = await data.chadex.connect(data.user3Signer).trade(Action.FillAnyAndAddOrder, BuySell.Buy, data.token0.target, data.weth.target, ethers.parseUnits(price1, 12), expiry, sellBaseTokens, []);
    // await data.printEvents("user3->chadex.trade(FillAnyAndAddOrder, BUY, token0, WETH, " + price1 + ", expiry, sellBaseTokens, [])", await trade4Tx.wait());
    // await data.printState("After Executing Against Orders");

    // // Delete orders
    const chadexData = await data.getChadexData();
    console.log();
    // const pairKeys = [];
    // const buySells = [];
    // const orders = [];
    // for (const [pairKey, pair] of Object.entries(chadexData)) {
    //   console.log("          Pair " + pairKey + " " + data.getShortAccountName(pair.baseToken) + " " + data.getShortAccountName(pair.quoteToken) + " " + pair.multiplier + " " + pair.divisor + " " + pair.baseDecimals + " " + pair.quoteDecimals);
    //   for (let buySell = 0; buySell < 2; buySell++) {
    //     const myOrders = pair.orders[buySell].filter(e => e.maker == data.user1).map(e => e.orderKey);
    //     if (myOrders.length > 0) {
    //       pairKeys.push(pairKey);
    //       buySells.push(buySell);
    //       orders.push(myOrders);
    //     }
    //   }
    // }
    // console.log("          pairKeys: " + JSON.stringify(pairKeys));
    // console.log("          buySells: " + JSON.stringify(buySells));
    // console.log("          orders: " + JSON.stringify(orders));
    // const removeOrders1Tx = await data.chadex.connect(data.user1Signer).removeOrders(pairKeys, buySells, orders);
    // await data.printEvents("user1->chadex.removeOrders(pairKeys, buySells, orders)", await removeOrders1Tx.wait());
    //
    // await data.printState("After Removing Orders");
  });
});


// it.skip("00. Test 00", async function () {
//   console.log("      00. Test 00 - Happy Path - Specified Set");
//
//   const tokenIds = [111, 333, 555];
//   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, "Odd TokenIds: - test", tokenIds);
//   await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());
//
//   const umswapAddress = await data.umswapFactory.umswaps(0);
//   const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
//   data.setUmswap(umswap);
//   await data.printState("Before setApprovalForAll");
//
//   const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
//   await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
//   await data.printState("Before Any Umswaps");
//
//   const swapInIds = [111, 333];
//   const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
//   await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
//   await data.printState("user0 swapped in " + JSON.stringify(swapInIds));
//
//   const transferAmount = "0.54321";
//   const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.parseEther(transferAmount));
//   await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
//   await data.printState("user0 transferred " + transferAmount + " umswaps to user1");
//
//   const swapOutIds1 = [111];
//   const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
//   await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
//   await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));
//
//   const approveAmount = "0.45679";
//   const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.parseEther(approveAmount));
//   await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
//   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");
//
//   const transferFromAmount = "0.45679";
//   const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.parseEther(transferFromAmount));
//   await data.printEvents("user1->umswap.transferFrom(user0, user1, " + transferFromAmount + ")", await transferFrom.wait());
//   await data.printState("user1 transferred " + transferFromAmount + " umswaps from user0");
//
//   const swapOutIds2 = [333];
//   const swapOut2Tx = await umswap.connect(data.user1Signer).swap([], swapOutIds2);
//   await data.printEvents("user1->umswap.swap([], " + JSON.stringify(swapOutIds2) + ", ...)", await swapOut2Tx.wait());
//   await data.printState("user1 swapped out " + JSON.stringify(swapOutIds2));
// });


// it.skip("01. Test 01", async function () {
//   console.log("      01. Test 01 - Happy Path - Whole Collection");
//
//   const tokenIds = [];
//   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, "Odd TokenIds: - test", tokenIds);
//   await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());
//
//   const umswapAddress = await data.umswapFactory.umswaps(0);
//   const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
//   data.setUmswap(umswap);
//
//   const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
//   await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
//   await data.printState("Before Any Umswaps");
//
//   const swapInIds = [111, 333];
//   const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
//   await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
//   await data.printState("user0 swapped in " + JSON.stringify(swapInIds));
//
//   const transferAmount = "0.54321";
//   const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.parseEther(transferAmount));
//   await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
//   await data.printState("user0 transferred " + transferAmount + " umswaps to user1");
//
//   const swapOutIds1 = [111];
//   const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
//   await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
//   await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));
//
//   const approveAmount = "0.45679";
//   const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.parseEther(approveAmount));
//   await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
//   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");
//
//   const transferFromAmount = "0.45679";
//   const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.parseEther(transferFromAmount));
//   await data.printEvents("user1->umswap.transferFrom(user0, user1, " + transferFromAmount + ")", await transferFrom.wait());
//   await data.printState("user1 transferred " + transferFromAmount + " umswaps from user0");
//
//   const swapOutIds2 = [333];
//   const swapOut2Tx = await umswap.connect(data.user1Signer).swap([], swapOutIds2);
//   await data.printEvents("user1->umswap.swap([], " + JSON.stringify(swapOutIds2) + ", ...)", await swapOut2Tx.wait());
//   await data.printState("user1 swapped out " + JSON.stringify(swapOutIds2));
// });


// it.skip("02. Test 02", async function () {
//   console.log("      02. Test 02 - Get Data");
//   for (let numberOfTokenIds of [10, 20, 30]) {
//     for (let rangeStart of [0, 65]) {
//       let tokenIds = generateRange(rangeStart, parseInt(rangeStart) + numberOfTokenIds, 1);
//       const name = "Set size " + numberOfTokenIds + " starting " + rangeStart;
//       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, name, tokenIds);
//       await data.printEvents(name, await newUmswapTx.wait());
//     }
//   }
//   await data.printState("End");
// });


// it.skip("03. Test 03", async function () {
//   console.log("      03. Test 03 - New Umswaps with 16, 32, 64 and 256 bit tokenId collections. Note > 2 ** 64 x 1200 close to failure at the current 30m block gas limit");
//   for (let numberOfTokenIds of [10, 100, 1200]) {
//     for (let rangeStart of ["0x0", "0xffff", "0xffffffff", "0xffffffffffffffff"]) {
//       let tokenIds = generateRange(0, numberOfTokenIds, 1);
//       const rangeStartBN = ethers.BigNumber.from(rangeStart);
//       tokenIds = tokenIds.map((i) => rangeStartBN.add(i));
//       const name = numberOfTokenIds + " #s from " + rangeStart;
//       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, name, tokenIds);
//       await data.printEvents(name, await newUmswapTx.wait());
//     }
//   }
//   console.log("      02. Test 02 - New Umswaps with 16 bit tokenId collections. Note < 2 ** 16 x 3800 close to the current 30m block gas limit. 4k fails");
//   for (let numberOfTokenIds of [3800]) {
//     for (let rangeStart of [0]) {
//       let tokenIds = generateRange(rangeStart, parseInt(rangeStart) + numberOfTokenIds, 1);
//       const name = numberOfTokenIds + " items from " + rangeStart;
//       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, name, tokenIds);
//       await data.printEvents(name, await newUmswapTx.wait());
//     }
//   }
//   await data.printState("End");
// });
//
//
// it.skip("04. Test 04", async function () {
//   console.log("      04. Test 04 - UmswapFactory Exceptions");
//
//   await expect(
//     data.umswapFactory.newUmswap(data.user0, "name", [111, 222, 333])
//   ).to.be.revertedWithCustomError(data.umswapFactory, "NotERC721");
//   console.log("        Tested newUmswap(...) for error 'NotERC721'");
//
//   await expect(
//     data.umswapFactory.newUmswap(data.erc721Mock.target, "name🤪", [111, 222, 333])
//   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidName");
//   console.log("        Tested newUmswap(...) for error 'InvalidName'");
//
//   await expect(
//     data.umswapFactory.newUmswap(data.erc721Mock.target, "name", [222, 222, 333])
//   ).to.be.revertedWithCustomError(data.umswapFactory, "TokenIdsMustBeSortedWithNoDuplicates");
//   console.log("        Tested newUmswap(...) for error 'TokenIdsMustBeSortedWithNoDuplicates'");
//
//   const firstTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, "name1", [111, 222, 333]);
//   await expect(
//     data.umswapFactory.newUmswap(data.erc721Mock.target, "name2", [111, 222, 333])
//   ).to.be.revertedWithCustomError(data.umswapFactory, "DuplicateSet");
//   console.log("        Tested newUmswap(...) for error 'DuplicateSet'");
//
//   await expect(
//     data.erc721Mock.connect(data.user0Signer)["safeTransferFrom(address,address,uint256)"](data.user0, data.umswapFactory.target, 111)
//   ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
//   console.log("        Tested ERC-721 safeTransferFrom(user, umswapFactory, 111) for error 'ERC721: transfer to non ERC721Receiver implementer'");
//
//   await expect(
//     data.user0Signer.sendTransaction({ to: data.umswapFactory.target, value: ethers.parseEther("1.0") })
//   ).to.be.reverted;
//   console.log("        Tested sending ETH to umswapFactory for revert");
// });


// it.skip("05. Test 05", async function () {
//   console.log("      05. Test 05 - Umswap Additional Tests");
//
//   const tokenIds = [111, 333, 555];
//   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.target, "Test Name :#'()+,-", tokenIds);
//   await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());
//
//   const umswapsLength = await data.umswapFactory.getUmswapsLength();
//   expect(await data.umswapFactory.getUmswapsLength()).to.equal(1);
//   console.log("        Tested newUmswap(...) - success");
//
//   const umswapAddress = await data.umswapFactory.umswaps(0);
//   const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
//   data.setUmswap(umswap);
//
//   const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
//   await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
//   await data.printState("Before Any Umswaps");
//
//   await expect(
//     data.erc721Mock.connect(data.user0Signer)["safeTransferFrom(address,address,uint256)"](data.user0, umswapAddress, 111)
//   ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
//   console.log("        Tested ERC-721 safeTransferFrom(user, umswap, 111) for error 'ERC721: transfer to non ERC721Receiver implementer'");
//
//   const swapInIds = [111, 333];
//   const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
//   await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
//   await data.printState("user0 swapped in " + JSON.stringify(swapInIds));
//
//   const rate1Tx =  await umswap.connect(data.user0Signer).rate(5, "Yeah 5");
//   await data.printEvents("user0->rate(5, 'Yeah', ...)", await rate1Tx.wait());
//   await data.printState("user0 rated 5");
//
//   const rate2Tx =  await umswap.connect(data.user1Signer).rate(6, "Yeah 6");
//   await data.printEvents("user1->rate(6, 'Yeah', ...)", await rate2Tx.wait());
//   await data.printState("user1 rated 6");
//
//   const rate3Tx =  await umswap.connect(data.user0Signer).rate(10, "Yeah 10");
//   await data.printEvents("user0->rate(10, 'Yeah', ...)", await rate3Tx.wait());
//   await data.printState("user0 rated 10");
//
//   const sendMessage1Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, ZERO_ADDRESS, "Topic 1", "Hello world!");
//   await data.printEvents("user1->sendMessage(0x0, 0x0, 'Hello world!', ...)", await sendMessage1Tx.wait());
//
//   const sendMessage2Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, umswap.target, "Topic 2", "Hello world! - specific umswap");
//   await data.printEvents("user1->sendMessage(0x0, umswap, 'Hello world!', ...)", await sendMessage2Tx.wait());
//
//   const sendMessage3Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, data.erc721Mock.target, "Topic 2", "Hello world! - specific umswap");
//   await data.printEvents("user1->sendMessage(0x0, ERC-721, 'Hello world!', ...)", await sendMessage3Tx.wait());
//
//   const blah1 = "🤪 Blah ".repeat(280/10);
//   const sendMessage4Tx =  await data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, ZERO_ADDRESS, "Topic 3", blah1);
//   await data.printEvents("user2->sendMessage(0x0, 0x0, '(long message)', ...)", await sendMessage4Tx.wait());
//
//   await expect(
//     data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidTopic    1234567890123456789", "Hello world!")
//   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidTopic");
//   console.log("        Tested sendMessage(...) for error 'InvalidTopic'");
//
//   await expect(
//     data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidUmswapOrCollection - EOA", "Hello world!")
//   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidUmswapOrCollection");
//   console.log("        Tested sendMessage(...) for error 'InvalidUmswapOrCollection - EOA'");
//
//   await expect(
//     data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.umswapFactory.target, "Should Fail - InvalidUmswapOrCollection", "Hello world!")
//   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidUmswapOrCollection");
//   console.log("        Tested sendMessage(...) for error 'InvalidUmswapOrCollection - Contract'");
//
//   const blah2 = "Blah".repeat(280/4) + "a";
//   await expect(
//     data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidMessage", blah2)
//   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidMessage");
//   console.log("        Tested sendMessage(...) for error 'InvalidMessage'");
//
//   await expect(
//     data.user0Signer.sendTransaction({ to: umswapAddress, value: ethers.parseEther("1.0") })
//   ).to.be.reverted;
//   console.log("        Tested sending ETH to umswap for revert");
//
//   await data.printState("end");
// });
