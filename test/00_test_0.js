const { ZERO_ADDRESS, BUYORSELL, ANYORALL, BUYORSELLSTRING, ANYORALLSTRING, Data, generateRange } = require('./helpers/common');
const { singletons, expectRevert } = require("@openzeppelin/test-helpers");
const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const util = require('util');

const BUYSELL_BUY = 0;
const BUYSELL_SELL = 1;

const FILL_ANY = 0;
const FILL_ALL_OR_NOTHING = 1;
const FILL_ANY_AND_ADD_ORDER = 2;

let data;

describe("Dexz", function () {
  const DETAILS = 1;

  beforeEach(async function () {
    console.log();
    console.log("      beforeEach");
    const Token  = await ethers.getContractFactory("Token");
    const Weth  = await ethers.getContractFactory("WETH9");
    const Dexz  = await ethers.getContractFactory("Dexz");
    data = new Data();
    await data.init();

    console.log("        --- Setup Tokens and Dexz Contracts. Assuming gasPrice: " + ethers.utils.formatUnits(data.gasPrice, "gwei") + " gwei, ethUsd: " + ethers.utils.formatUnits(data.ethUsd, 18) + " ---");

    const token0 = await Token.deploy("TOK0", "Token0", 18, ethers.utils.parseUnits("500", 18));
    // const token0 = await Token.deploy("TOK0", "Token0", 18, ethers.utils.parseUnits("20000", 18));
    await token0.deployed();
    await data.setToken0(token0);
    const token0Receipt = await data.token0.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed Token0", token0Receipt);
    }
    console.log("        Token0 deployed");

    const token1 = await Token.deploy("TOK1", "Token1", 18, ethers.utils.parseUnits("5000", 18));
    await token1.deployed();
    await data.setToken1(token1);
    const token1Receipt = await data.token1.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed Token1", token1Receipt);
    }
    console.log("        Token1 deployed");

    const weth = await Weth.deploy();
    await weth.deployed();
    await data.setWeth(weth);
    const wethReceipt = await data.weth.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed WETH", wethReceipt);
    }
    console.log("        WETH deployed");

    const dexz = await Dexz.deploy(data.feeAccount);
    await dexz.deployed();
    await data.setDexz(dexz);
    const dexzReceipt = await data.dexz.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed Dexz", dexzReceipt);
    }
    console.log("        Dexz deployed");

    const setup1 = [];
    setup1.push(token0.transfer(data.user0, ethers.utils.parseUnits("100", 18)));
    setup1.push(token0.transfer(data.user1, ethers.utils.parseUnits("100", 18)));
    setup1.push(token0.transfer(data.user2, ethers.utils.parseUnits("100", 18)));
    setup1.push(token0.transfer(data.user3, ethers.utils.parseUnits("100", 18)));
    const [transferToken00Tx, transferToken01Tx, transferToken02Tx, transferToken03Tx] = await Promise.all(setup1);
    if (DETAILS > 0) {
      [transferToken00Tx, transferToken01Tx, transferToken02Tx, transferToken03Tx].forEach( async function (a) {
        await data.printEvents("Transfer Token0", await a.wait());
      });
    }
    const setup2 = [];
    setup2.push(token1.transfer(data.user0, ethers.utils.parseEther("1000")));
    setup2.push(token1.transfer(data.user1, ethers.utils.parseEther("1000")));
    setup2.push(token1.transfer(data.user2, ethers.utils.parseEther("1000")));
    setup2.push(token1.transfer(data.user3, ethers.utils.parseEther("1000")));
    const [transferToken10Tx, transferToken11Tx, transferToken12Tx, transferToken13Tx] = await Promise.all(setup2);
    if (DETAILS > 0) {
      [transferToken10Tx, transferToken11Tx, transferToken12Tx, transferToken13Tx].forEach( async function (a) {
        await data.printEvents("Transfer Token1", await a.wait());
      });
    }
    console.log("        Tokens transferred");

    const wethAmount = ethers.utils.parseEther("100");

    const weth0Tx = await data.user0Signer.sendTransaction({ to: data.weth.address, value: wethAmount });
    const weth1Tx = await data.user1Signer.sendTransaction({ to: data.weth.address, value: wethAmount });
    const weth2Tx = await data.user2Signer.sendTransaction({ to: data.weth.address, value: wethAmount });
    const weth3Tx = await data.user3Signer.sendTransaction({ to: data.weth.address, value: wethAmount });
    await data.printEvents("Send weth" , await weth0Tx.wait());
    await data.printEvents("Send weth" , await weth1Tx.wait());
    await data.printEvents("Send weth" , await weth2Tx.wait());
    await data.printEvents("Send weth" , await weth3Tx.wait());

    const approveAmount = ethers.utils.parseEther("1000");
    const approve00Tx = await data.token0.connect(data.user0Signer).approve(data.dexz.address, approveAmount);
    const approve10Tx = await data.token1.connect(data.user0Signer).approve(data.dexz.address, approveAmount);
    const approve20Tx = await data.weth.connect(data.user0Signer).approve(data.dexz.address, approveAmount);

    const approve01Tx = await data.token0.connect(data.user1Signer).approve(data.dexz.address, approveAmount);
    const approve11Tx = await data.token1.connect(data.user1Signer).approve(data.dexz.address, approveAmount);
    const approve21Tx = await data.weth.connect(data.user1Signer).approve(data.dexz.address, approveAmount);

    const approve02Tx = await data.token0.connect(data.user2Signer).approve(data.dexz.address, approveAmount);
    const approve12Tx = await data.token1.connect(data.user2Signer).approve(data.dexz.address, approveAmount);
    const approve22Tx = await data.weth.connect(data.user2Signer).approve(data.dexz.address, approveAmount);

    const approve03Tx = await data.token0.connect(data.user3Signer).approve(data.dexz.address, approveAmount);
    const approve13Tx = await data.token1.connect(data.user3Signer).approve(data.dexz.address, approveAmount);
    const approve23Tx = await data.weth.connect(data.user3Signer).approve(data.dexz.address, approveAmount);

    await data.printEvents("user0->token0.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve00Tx.wait());
    await data.printEvents("user0->token1.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve10Tx.wait());
    await data.printEvents("user0->weth.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve20Tx.wait());
    await data.printEvents("user1->token0.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve01Tx.wait());
    await data.printEvents("user1->token1.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve11Tx.wait());
    await data.printEvents("user1->weth.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve21Tx.wait());

    await data.printEvents("user2->token0.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve02Tx.wait());
    await data.printEvents("user2->token1.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve12Tx.wait());
    await data.printEvents("user2->weth.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve22Tx.wait());

    await data.printEvents("user3->token0.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve03Tx.wait());
    await data.printEvents("user3->token1.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve13Tx.wait());
    await data.printEvents("user3->weth.approve(dexz, " + ethers.utils.formatEther(approveAmount) + ")", await approve23Tx.wait());

    //   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");

    await data.printState("Setup Completed. Dexz bytecode ~" + JSON.stringify(data.dexz.deployTransaction.data.length/2, null, 2));
  });

  it("00. Test 00", async function () {
    console.log("      00. Test 00 - Happy Path - Specified Set");

    // function trade(uint orderFlag, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 _orderKey) {

    const price1 = "0.69";
    const price2 = "0.6901";
    const price3 = "0.6902";
    // const price = ethers.utils.parseUnits("500", 18);
    const expired = parseInt(new Date()/1000) - 60*60;
    const expiry = parseInt(new Date()/1000) + 60*60;
    const baseTokens1 = ethers.utils.parseEther("1");
    const baseTokens2 = ethers.utils.parseEther("2");
    const baseTokens3 = ethers.utils.parseEther("3");

    const trade1aTx = await data.dexz.connect(data.user0Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price1, 9), expiry, baseTokens1, data.uiFeeAccount);
    await data.printEvents("user0->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price1 + ", expiry, baseTokens1, uiFeeAccount)", await trade1aTx.wait());

    const trade2aTx = await data.dexz.connect(data.user1Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price1, 9), expiry, baseTokens2, data.uiFeeAccount);
    await data.printEvents("user1->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price1 + ", expiry, baseTokens2, uiFeeAccount)", await trade2aTx.wait());

    const trade3aTx = await data.dexz.connect(data.user2Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price1, 9), expiry, baseTokens3, data.uiFeeAccount);
    await data.printEvents("user2->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price1 + ", expiry, baseTokens3, uiFeeAccount)", await trade3aTx.wait());

    const trade1bTx = await data.dexz.connect(data.user0Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price2, 9), expiry, baseTokens1, data.uiFeeAccount);
    await data.printEvents("user0->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price2 + ", expiry, baseTokens1, uiFeeAccount)", await trade1bTx.wait());

    const trade2bTx = await data.dexz.connect(data.user1Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price2, 9), expiry, baseTokens2, data.uiFeeAccount);
    await data.printEvents("user1->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price2 + ", expiry, baseTokens2, uiFeeAccount)", await trade2bTx.wait());

    const trade3bTx = await data.dexz.connect(data.user2Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price2, 9), expiry, baseTokens3, data.uiFeeAccount);
    await data.printEvents("user2->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price2 + ", expiry, baseTokens3, uiFeeAccount)", await trade3bTx.wait());

    const trade1cTx = await data.dexz.connect(data.user0Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price3, 9), expiry, baseTokens1, data.uiFeeAccount);
    await data.printEvents("user0->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price3 + ", expiry, baseTokens1, uiFeeAccount)", await trade1cTx.wait());

    const trade2cTx = await data.dexz.connect(data.user1Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price3, 9), expiry, baseTokens2, data.uiFeeAccount);
    await data.printEvents("user1->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price3 + ", expiry, baseTokens2, uiFeeAccount)", await trade2cTx.wait());

    const trade3cTx = await data.dexz.connect(data.user2Signer).trade(BUYSELL_BUY, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price3, 9), expiry, baseTokens3, data.uiFeeAccount);
    await data.printEvents("user2->dexz.trade(BUY, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price3 + ", expiry, baseTokens3, uiFeeAccount)", await trade3cTx.wait());

    await data.printState("After Adding Order(s)");

    const sellBaseTokens = ethers.utils.parseEther("90");

    // const FILL_ANY = 0;
    // const FILL_ALL_OR_NOTHING = 1;
    // const FILL_ANY_AND_ADD_ORDER = 2;


    const trade4Tx = await data.dexz.connect(data.user3Signer).trade(BUYSELL_SELL, FILL_ANY_AND_ADD_ORDER, data.token0.address, data.weth.address, ethers.utils.parseUnits(price2, 9), expiry, sellBaseTokens, data.uiFeeAccount);
    await data.printEvents("user3->dexz.trade(SELL, FILL_ANY_AND_ADD_ORDER, token0, WETH, " + price2 + ", expiry, sellBaseTokens, uiFeeAccount)", await trade4Tx.wait());

    await data.printState("After Executing Against Order(s)");




    // const newUmswapTx = await data.dexz.newUmswap(data.erc721Mock.address, "Odd TokenIds: - test", tokenIds);
    // await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());
  });

  // it.skip("00. Test 00", async function () {
  //   console.log("      00. Test 00 - Happy Path - Specified Set");
  //
  //   const tokenIds = [111, 333, 555];
  //   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Odd TokenIds: - test", tokenIds);
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
  //   const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.utils.parseEther(transferAmount));
  //   await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
  //   await data.printState("user0 transferred " + transferAmount + " umswaps to user1");
  //
  //   const swapOutIds1 = [111];
  //   const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
  //   await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
  //   await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));
  //
  //   const approveAmount = "0.45679";
  //   const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.utils.parseEther(approveAmount));
  //   await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
  //   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");
  //
  //   const transferFromAmount = "0.45679";
  //   const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.utils.parseEther(transferFromAmount));
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
  //   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Odd TokenIds: - test", tokenIds);
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
  //   const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.utils.parseEther(transferAmount));
  //   await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
  //   await data.printState("user0 transferred " + transferAmount + " umswaps to user1");
  //
  //   const swapOutIds1 = [111];
  //   const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
  //   await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
  //   await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));
  //
  //   const approveAmount = "0.45679";
  //   const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.utils.parseEther(approveAmount));
  //   await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
  //   await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");
  //
  //   const transferFromAmount = "0.45679";
  //   const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.utils.parseEther(transferFromAmount));
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
  //       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
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
  //       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
  //       await data.printEvents(name, await newUmswapTx.wait());
  //     }
  //   }
  //   console.log("      02. Test 02 - New Umswaps with 16 bit tokenId collections. Note < 2 ** 16 x 3800 close to the current 30m block gas limit. 4k fails");
  //   for (let numberOfTokenIds of [3800]) {
  //     for (let rangeStart of [0]) {
  //       let tokenIds = generateRange(rangeStart, parseInt(rangeStart) + numberOfTokenIds, 1);
  //       const name = numberOfTokenIds + " items from " + rangeStart;
  //       const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
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
  //     data.umswapFactory.newUmswap(data.erc721Mock.address, "name🤪", [111, 222, 333])
  //   ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidName");
  //   console.log("        Tested newUmswap(...) for error 'InvalidName'");
  //
  //   await expect(
  //     data.umswapFactory.newUmswap(data.erc721Mock.address, "name", [222, 222, 333])
  //   ).to.be.revertedWithCustomError(data.umswapFactory, "TokenIdsMustBeSortedWithNoDuplicates");
  //   console.log("        Tested newUmswap(...) for error 'TokenIdsMustBeSortedWithNoDuplicates'");
  //
  //   const firstTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "name1", [111, 222, 333]);
  //   await expect(
  //     data.umswapFactory.newUmswap(data.erc721Mock.address, "name2", [111, 222, 333])
  //   ).to.be.revertedWithCustomError(data.umswapFactory, "DuplicateSet");
  //   console.log("        Tested newUmswap(...) for error 'DuplicateSet'");
  //
  //   await expect(
  //     data.erc721Mock.connect(data.user0Signer)["safeTransferFrom(address,address,uint256)"](data.user0, data.umswapFactory.address, 111)
  //   ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
  //   console.log("        Tested ERC-721 safeTransferFrom(user, umswapFactory, 111) for error 'ERC721: transfer to non ERC721Receiver implementer'");
  //
  //   await expect(
  //     data.user0Signer.sendTransaction({ to: data.umswapFactory.address, value: ethers.utils.parseEther("1.0") })
  //   ).to.be.reverted;
  //   console.log("        Tested sending ETH to umswapFactory for revert");
  // });


  // it.skip("05. Test 05", async function () {
  //   console.log("      05. Test 05 - Umswap Additional Tests");
  //
  //   const tokenIds = [111, 333, 555];
  //   const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Test Name :#'()+,-", tokenIds);
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
  //   const sendMessage2Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, umswap.address, "Topic 2", "Hello world! - specific umswap");
  //   await data.printEvents("user1->sendMessage(0x0, umswap, 'Hello world!', ...)", await sendMessage2Tx.wait());
  //
  //   const sendMessage3Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, data.erc721Mock.address, "Topic 2", "Hello world! - specific umswap");
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
  //     data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.umswapFactory.address, "Should Fail - InvalidUmswapOrCollection", "Hello world!")
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
  //     data.user0Signer.sendTransaction({ to: umswapAddress, value: ethers.utils.parseEther("1.0") })
  //   ).to.be.reverted;
  //   console.log("        Tested sending ETH to umswap for revert");
  //
  //   await data.printState("end");
  // });
});
