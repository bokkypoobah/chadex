const { ZERO_ADDRESS, BUYORSELL, ANYORALL, BUYORSELLSTRING, ANYORALLSTRING, Data, generateRange } = require('./helpers/common');
const { singletons, expectRevert } = require("@openzeppelin/test-helpers");
const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const util = require('util');

let data;

describe("Dexz", function () {
  const DETAILS = 1;

  beforeEach(async function () {
    console.log();
    console.log("      beforeEach");
    const Token  = await ethers.getContractFactory("Token");
    const Dexz  = await ethers.getContractFactory("Dexz");
    data = new Data();
    await data.init();

    console.log("        --- Setup Accounts, NFT and Umswap Contracts - Assuming gasPrice: " + ethers.utils.formatUnits(data.gasPrice, "gwei") + " gwei, ethUsd: " + ethers.utils.formatUnits(data.ethUsd, 18) + " ---");

    const token0 = await Token.deploy("TOK0", "Token0", 18, "1234567890123456789012");
    await token0.deployed();
    await data.setToken0(token0);
    const token0Receipt = await data.token0.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed Token0", token0Receipt);
    }
    console.log("        token0 deployed");

    const token1 = await Token.deploy("TOK1", "Token1", 18, "2345678901234567890123");
    await token1.deployed();
    await data.setToken1(token1);
    const token1Receipt = await data.token1.deployTransaction.wait();
    if (DETAILS > 0) {
      await data.printEvents("Deployed Token1", token1Receipt);
    }
    console.log("        token1 deployed");


    // const umswapFactory = await UmswapFactory.deploy();
    // await umswapFactory.deployed();
    // await data.setUmswapFactory(umswapFactory);
    // const umswapFactoryReceipt = await data.umswapFactory.deployTransaction.wait();
    // if (DETAILS > 0) {
    //   await data.printEvents("Deployed UmswapFactory", umswapFactoryReceipt);
    // }
    // console.log("        UmswapFactory deployed");
    //
    // const setup1 = [];
    // setup1.push(data.erc721Mock.mint(data.user0, 111));
    // setup1.push(data.erc721Mock.mint(data.user0, 222));
    // setup1.push(data.erc721Mock.mint(data.user0, 333));
    // setup1.push(data.erc721Mock.mint(data.user1, 444));
    // setup1.push(data.erc721Mock.mint(data.user1, 555));
    // setup1.push(data.erc721Mock.mint(data.user1, 666));
    // const mintATxs = await Promise.all(setup1);
    // if (DETAILS > 0) {
    //   mintATxs.forEach( async function (a) {
    //     await data.printEvents("Minted ERC721Mock", await a.wait());
    //   });
    // }
    // await data.printState("Setup Completed. UmswapFactory bytecode ~" + JSON.stringify(data.umswapFactory.deployTransaction.data.length/2, null, 2));
  });

  it("00. Test 00", async function () {
    console.log("      00. Test 00 - Happy Path - Specified Set");
  });

  it.skip("00. Test 00", async function () {
    console.log("      00. Test 00 - Happy Path - Specified Set");

    const tokenIds = [111, 333, 555];
    const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Odd TokenIds: - test", tokenIds);
    await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());

    const umswapAddress = await data.umswapFactory.umswaps(0);
    const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
    data.setUmswap(umswap);
    await data.printState("Before setApprovalForAll");

    const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
    await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
    await data.printState("Before Any Umswaps");

    const swapInIds = [111, 333];
    const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
    await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
    await data.printState("user0 swapped in " + JSON.stringify(swapInIds));

    const transferAmount = "0.54321";
    const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.utils.parseEther(transferAmount));
    await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
    await data.printState("user0 transferred " + transferAmount + " umswaps to user1");

    const swapOutIds1 = [111];
    const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
    await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
    await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));

    const approveAmount = "0.45679";
    const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.utils.parseEther(approveAmount));
    await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
    await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");

    const transferFromAmount = "0.45679";
    const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.utils.parseEther(transferFromAmount));
    await data.printEvents("user1->umswap.transferFrom(user0, user1, " + transferFromAmount + ")", await transferFrom.wait());
    await data.printState("user1 transferred " + transferFromAmount + " umswaps from user0");

    const swapOutIds2 = [333];
    const swapOut2Tx = await umswap.connect(data.user1Signer).swap([], swapOutIds2);
    await data.printEvents("user1->umswap.swap([], " + JSON.stringify(swapOutIds2) + ", ...)", await swapOut2Tx.wait());
    await data.printState("user1 swapped out " + JSON.stringify(swapOutIds2));
  });


  it.skip("01. Test 01", async function () {
    console.log("      01. Test 01 - Happy Path - Whole Collection");

    const tokenIds = [];
    const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Odd TokenIds: - test", tokenIds);
    await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());

    const umswapAddress = await data.umswapFactory.umswaps(0);
    const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
    data.setUmswap(umswap);

    const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
    await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
    await data.printState("Before Any Umswaps");

    const swapInIds = [111, 333];
    const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
    await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
    await data.printState("user0 swapped in " + JSON.stringify(swapInIds));

    const transferAmount = "0.54321";
    const transfer1Tx = await umswap.connect(data.user0Signer).transfer(data.user1, ethers.utils.parseEther(transferAmount));
    await data.printEvents("user0->umswap.transfer(user1, " + transferAmount + ")", await transfer1Tx.wait());
    await data.printState("user0 transferred " + transferAmount + " umswaps to user1");

    const swapOutIds1 = [111];
    const swapOut1Tx = await umswap.connect(data.user0Signer).swap([], swapOutIds1);
    await data.printEvents("user0->umswap.swap([], " + JSON.stringify(swapOutIds1) + ", ...)", await swapOut1Tx.wait());
    await data.printState("user0 swapped out " + JSON.stringify(swapOutIds1));

    const approveAmount = "0.45679";
    const approve1Tx = await umswap.connect(data.user0Signer).approve(data.user1, ethers.utils.parseEther(approveAmount));
    await data.printEvents("user0->umswap.approve(user1, " + approveAmount + ")", await approve1Tx.wait());
    await data.printState("user0 approved user1 to transfer " + approveAmount + " umswaps");

    const transferFromAmount = "0.45679";
    const transferFrom = await umswap.connect(data.user1Signer).transferFrom(data.user0, data.user1, ethers.utils.parseEther(transferFromAmount));
    await data.printEvents("user1->umswap.transferFrom(user0, user1, " + transferFromAmount + ")", await transferFrom.wait());
    await data.printState("user1 transferred " + transferFromAmount + " umswaps from user0");

    const swapOutIds2 = [333];
    const swapOut2Tx = await umswap.connect(data.user1Signer).swap([], swapOutIds2);
    await data.printEvents("user1->umswap.swap([], " + JSON.stringify(swapOutIds2) + ", ...)", await swapOut2Tx.wait());
    await data.printState("user1 swapped out " + JSON.stringify(swapOutIds2));
  });


  it.skip("02. Test 02", async function () {
    console.log("      02. Test 02 - Get Data");
    for (let numberOfTokenIds of [10, 20, 30]) {
      for (let rangeStart of [0, 65]) {
        let tokenIds = generateRange(rangeStart, parseInt(rangeStart) + numberOfTokenIds, 1);
        const name = "Set size " + numberOfTokenIds + " starting " + rangeStart;
        const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
        await data.printEvents(name, await newUmswapTx.wait());
      }
    }
    await data.printState("End");
  });


  it.skip("03. Test 03", async function () {
    console.log("      03. Test 03 - New Umswaps with 16, 32, 64 and 256 bit tokenId collections. Note > 2 ** 64 x 1200 close to failure at the current 30m block gas limit");
    for (let numberOfTokenIds of [10, 100, 1200]) {
      for (let rangeStart of ["0x0", "0xffff", "0xffffffff", "0xffffffffffffffff"]) {
        let tokenIds = generateRange(0, numberOfTokenIds, 1);
        const rangeStartBN = ethers.BigNumber.from(rangeStart);
        tokenIds = tokenIds.map((i) => rangeStartBN.add(i));
        const name = numberOfTokenIds + " #s from " + rangeStart;
        const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
        await data.printEvents(name, await newUmswapTx.wait());
      }
    }
    console.log("      02. Test 02 - New Umswaps with 16 bit tokenId collections. Note < 2 ** 16 x 3800 close to the current 30m block gas limit. 4k fails");
    for (let numberOfTokenIds of [3800]) {
      for (let rangeStart of [0]) {
        let tokenIds = generateRange(rangeStart, parseInt(rangeStart) + numberOfTokenIds, 1);
        const name = numberOfTokenIds + " items from " + rangeStart;
        const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, name, tokenIds);
        await data.printEvents(name, await newUmswapTx.wait());
      }
    }
    await data.printState("End");
  });


  it.skip("04. Test 04", async function () {
    console.log("      04. Test 04 - UmswapFactory Exceptions");

    await expect(
      data.umswapFactory.newUmswap(data.user0, "name", [111, 222, 333])
    ).to.be.revertedWithCustomError(data.umswapFactory, "NotERC721");
    console.log("        Tested newUmswap(...) for error 'NotERC721'");

    await expect(
      data.umswapFactory.newUmswap(data.erc721Mock.address, "name🤪", [111, 222, 333])
    ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidName");
    console.log("        Tested newUmswap(...) for error 'InvalidName'");

    await expect(
      data.umswapFactory.newUmswap(data.erc721Mock.address, "name", [222, 222, 333])
    ).to.be.revertedWithCustomError(data.umswapFactory, "TokenIdsMustBeSortedWithNoDuplicates");
    console.log("        Tested newUmswap(...) for error 'TokenIdsMustBeSortedWithNoDuplicates'");

    const firstTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "name1", [111, 222, 333]);
    await expect(
      data.umswapFactory.newUmswap(data.erc721Mock.address, "name2", [111, 222, 333])
    ).to.be.revertedWithCustomError(data.umswapFactory, "DuplicateSet");
    console.log("        Tested newUmswap(...) for error 'DuplicateSet'");

    await expect(
      data.erc721Mock.connect(data.user0Signer)["safeTransferFrom(address,address,uint256)"](data.user0, data.umswapFactory.address, 111)
    ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
    console.log("        Tested ERC-721 safeTransferFrom(user, umswapFactory, 111) for error 'ERC721: transfer to non ERC721Receiver implementer'");

    await expect(
      data.user0Signer.sendTransaction({ to: data.umswapFactory.address, value: ethers.utils.parseEther("1.0") })
    ).to.be.reverted;
    console.log("        Tested sending ETH to umswapFactory for revert");
  });


  it.skip("05. Test 05", async function () {
    console.log("      05. Test 05 - Umswap Additional Tests");

    const tokenIds = [111, 333, 555];
    const newUmswapTx = await data.umswapFactory.newUmswap(data.erc721Mock.address, "Test Name :#'()+,-", tokenIds);
    await data.printEvents("deployer->factory.newUmswap(erc721Mock, " + JSON.stringify(tokenIds) + ")", await newUmswapTx.wait());

    const umswapsLength = await data.umswapFactory.getUmswapsLength();
    expect(await data.umswapFactory.getUmswapsLength()).to.equal(1);
    console.log("        Tested newUmswap(...) - success");

    const umswapAddress = await data.umswapFactory.umswaps(0);
    const umswap  = await ethers.getContractAt("Umswap", umswapAddress);
    data.setUmswap(umswap);

    const approval1Tx = await data.erc721Mock.connect(data.user0Signer).setApprovalForAll(umswapAddress, true);
    await data.printEvents("user0->erc721Mock.setApprovalForAll(umswap, true)", await approval1Tx.wait());
    await data.printState("Before Any Umswaps");

    await expect(
      data.erc721Mock.connect(data.user0Signer)["safeTransferFrom(address,address,uint256)"](data.user0, umswapAddress, 111)
    ).to.be.revertedWith("ERC721: transfer to non ERC721Receiver implementer");
    console.log("        Tested ERC-721 safeTransferFrom(user, umswap, 111) for error 'ERC721: transfer to non ERC721Receiver implementer'");

    const swapInIds = [111, 333];
    const swapIn1Tx = await umswap.connect(data.user0Signer).swap(swapInIds, []);
    await data.printEvents("user0->umswap(" + JSON.stringify(swapInIds) + ", [], ...)", await swapIn1Tx.wait());
    await data.printState("user0 swapped in " + JSON.stringify(swapInIds));

    const rate1Tx =  await umswap.connect(data.user0Signer).rate(5, "Yeah 5");
    await data.printEvents("user0->rate(5, 'Yeah', ...)", await rate1Tx.wait());
    await data.printState("user0 rated 5");

    const rate2Tx =  await umswap.connect(data.user1Signer).rate(6, "Yeah 6");
    await data.printEvents("user1->rate(6, 'Yeah', ...)", await rate2Tx.wait());
    await data.printState("user1 rated 6");

    const rate3Tx =  await umswap.connect(data.user0Signer).rate(10, "Yeah 10");
    await data.printEvents("user0->rate(10, 'Yeah', ...)", await rate3Tx.wait());
    await data.printState("user0 rated 10");

    const sendMessage1Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, ZERO_ADDRESS, "Topic 1", "Hello world!");
    await data.printEvents("user1->sendMessage(0x0, 0x0, 'Hello world!', ...)", await sendMessage1Tx.wait());

    const sendMessage2Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, umswap.address, "Topic 2", "Hello world! - specific umswap");
    await data.printEvents("user1->sendMessage(0x0, umswap, 'Hello world!', ...)", await sendMessage2Tx.wait());

    const sendMessage3Tx =  await data.umswapFactory.connect(data.user1Signer).sendMessage(ZERO_ADDRESS, data.erc721Mock.address, "Topic 2", "Hello world! - specific umswap");
    await data.printEvents("user1->sendMessage(0x0, ERC-721, 'Hello world!', ...)", await sendMessage3Tx.wait());

    const blah1 = "🤪 Blah ".repeat(280/10);
    const sendMessage4Tx =  await data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, ZERO_ADDRESS, "Topic 3", blah1);
    await data.printEvents("user2->sendMessage(0x0, 0x0, '(long message)', ...)", await sendMessage4Tx.wait());

    await expect(
      data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidTopic    1234567890123456789", "Hello world!")
    ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidTopic");
    console.log("        Tested sendMessage(...) for error 'InvalidTopic'");

    await expect(
      data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidUmswapOrCollection - EOA", "Hello world!")
    ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidUmswapOrCollection");
    console.log("        Tested sendMessage(...) for error 'InvalidUmswapOrCollection - EOA'");

    await expect(
      data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.umswapFactory.address, "Should Fail - InvalidUmswapOrCollection", "Hello world!")
    ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidUmswapOrCollection");
    console.log("        Tested sendMessage(...) for error 'InvalidUmswapOrCollection - Contract'");

    const blah2 = "Blah".repeat(280/4) + "a";
    await expect(
      data.umswapFactory.connect(data.user2Signer).sendMessage(ZERO_ADDRESS, data.user0, "Should Fail - InvalidMessage", blah2)
    ).to.be.revertedWithCustomError(data.umswapFactory, "InvalidMessage");
    console.log("        Tested sendMessage(...) for error 'InvalidMessage'");

    await expect(
      data.user0Signer.sendTransaction({ to: umswapAddress, value: ethers.utils.parseEther("1.0") })
    ).to.be.reverted;
    console.log("        Tested sending ETH to umswap for revert");

    await data.printState("end");
  });
});
