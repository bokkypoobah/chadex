const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const BUYORSELL = { BUY: 0, SELL: 1 };
const ANYORALL = { ANY: 0, ALL: 1 };
const BUYORSELLSTRING = [ "Buy", "Sell" ];
const ANYORALLSTRING = [ "Any", "All" ];
const ORDERSTATUSSTRING = [ "Executable", "Disabled", "Expired", "Maxxed", "MakerNoWeth", "MakerNoWethAllowance", "MakerNoToken", "MakerNotApprovedNix", "UnknownError" ];

const { BigNumber } = require("ethers");
const util = require('util');
const { expect, assert } = require("chai");

class Data {

  constructor() {
    this.accounts = [];
    this.accountNames = {};
    this.contracts = [];

    this.erc721Mock = null;
    this.umswapFactory = null;
    this.umswap = null;

    this.gasPrice = ethers.utils.parseUnits("20", "gwei");
    this.ethUsd = ethers.utils.parseUnits("2000.00", 18);

    this.verbose = false;
  }

  async init() {
    [this.deployerSigner, this.user0Signer, this.user1Signer, this.user2Signer, this.integratorSigner] = await ethers.getSigners();
    [this.deployer, this.user0, this.user1, this.user2, this.integrator] = await Promise.all([this.deployerSigner.getAddress(), this.user0Signer.getAddress(), this.user1Signer.getAddress(), this.user2Signer.getAddress(), this.integratorSigner.getAddress()]);

    this.addAccount("0x0000000000000000000000000000000000000000", "null");
    this.addAccount(this.deployer, "deployer");
    this.addAccount(this.user0, "user0");
    this.addAccount(this.user1, "user1");
    this.addAccount(this.user2, "user2");
    this.addAccount(this.integrator, "integrator");
    this.baseBlock = await ethers.provider.getBlockNumber();
  }

  addAccount(account, accountName) {
    this.accounts.push(account);
    this.accountNames[account.toLowerCase()] = accountName;
    if (this.verbose) {
      console.log("      Mapping account " + account + " => " + this.getShortAccountName(account));
    }
  }
  getShortAccountName(address) {
    if (address != null) {
      var a = address.toLowerCase();
      var n = this.accountNames[a];
      if (n !== undefined) {
        return n + ":" + address.substring(0, 6);
      }
    }
    return address.substring(0, 20);
  }
  addContract(contract, contractName) {
    const address = contract.address;
    this.accounts.push(address);
    this.accountNames[address.toLowerCase()] = contractName;
    this.contracts.push(contract);
    if (this.verbose) {
      console.log("      Mapping contract " + address + " => " + this.getShortAccountName(address));
    }
  }


  printEvents(prefix, receipt) {
    var fee = receipt.gasUsed.mul(this.gasPrice);
    var feeUsd = fee.mul(this.ethUsd).div(ethers.utils.parseUnits("1", 18)).div(ethers.utils.parseUnits("1", 18));
    console.log("        > " + prefix + " - gasUsed: " + receipt.gasUsed + " ~ ETH " + ethers.utils.formatEther(fee) + " ~ USD " + feeUsd);
    receipt.logs.forEach((log) => {
      let found = false;
      for (let i = 0; i < this.contracts.length && !found; i++) {
        try {
          var data = this.contracts[i].interface.parseLog(log);
          var result = data.name + "(";
          let separator = "";
          data.eventFragment.inputs.forEach((a) => {
            result = result + separator + a.name + ": ";
            if (a.type == 'address') {
              result = result + this.getShortAccountName(data.args[a.name].toString());
            } else if (a.type == 'uint256' || a.type == 'uint128') {
              if (a.name == 'tokens' || a.name == 'amount' || a.name == 'balance' || a.name == 'value' || a.name == 'integratorTip' || a.name == 'remainingTip') {
                result = result + ethers.utils.formatUnits(data.args[a.name], 18);
              } else {
                result = result + data.args[a.name].toString();
              }
            } else {
              result = result + data.args[a.name].toString();
            }
            separator = ", ";
          });
          result = result + ")";
          console.log("          + " + this.getShortAccountName(log.address) + " " + log.blockNumber + "." + log.logIndex + " " + result);
          found = true;
        } catch (e) {
        }
      }
      if (!found) {
        console.log("        + " + this.getShortAccountName(log.address) + " " + JSON.stringify(log.topics));
      }
    });
  }

  padLeft(s, n) {
    var o = s.toString();
    while (o.length < n) {
      o = " " + o;
    }
    return o;
  }
  padLeft0(s, n) {
    var result = s.toString();
    while (result.length < n) {
      result = "0" + result;
    }
    return result;
  }
  padRight(s, n) {
    var o = s;
    while (o.length < n) {
      o = o + " ";
    }
    return o;
  }

  async setERC721Mock(erc721Mock) {
    this.erc721Mock = erc721Mock;
    this.addContract(erc721Mock, "ERC721Mock");
  }
  async setUmswapFactory(umswapFactory) {
    this.umswapFactory = umswapFactory;
    this.addContract(umswapFactory, "UmswapFactory");
  }
  async setUmswap(umswap) {
    this.umswap = umswap;
    this.addContract(umswap, "Umswap");
  }

  async printState(prefix) {
    console.log("\n        --- " + prefix + " ---");

    let erc721TotalSupply = 0;
    const owners = {};
    if (this.erc721Mock != null) {
      erc721TotalSupply = await this.erc721Mock.totalSupply();
      for (let i = 0; i < erc721TotalSupply; i++) {
        const tokenId = await this.erc721Mock.tokenByIndex(i);
        const ownerOf = await this.erc721Mock.ownerOf(tokenId);
        if (!owners[ownerOf]) {
          owners[ownerOf] = [];
        }
        owners[ownerOf].push(parseInt(tokenId));
      }
    }
    let umswapSymbol = "??????";
    let umswapTotalSupply = 0;
    let umswapDecimals = null;
    if (this.umswap != null) {
      umswapSymbol = await this.umswap.symbol();
      umswapTotalSupply = ethers.utils.formatEther(await this.umswap.totalSupply());
      umswapDecimals = await this.umswap.decimals();
    }
    let umswapTitle = umswapSymbol.toString().substring(0, 10) + " (" + umswapDecimals + ") " + umswapTotalSupply;
    if (umswapTitle.length < 23) {
      umswapTitle = " ".repeat(23 - umswapTitle.length) + umswapTitle;
    }

    console.log("          Account                                   ETH " + umswapTitle + " " + this.padRight(await this.erc721Mock.symbol() + " (" + erc721TotalSupply + ")", 25));
    console.log("          -------------------- ------------------------ ----------------------- ---------------------------------------------");
    const checkAccounts = [this.deployer, this.user0, this.user1, this.user2, this.integrator];
    if (this.umswapFactory != null) {
      checkAccounts.push(this.umswapFactory.address);
    }
    if (this.umswap != null) {
      checkAccounts.push(this.umswap.address);
    }
    for (let i = 0; i < checkAccounts.length; i++) {
      const ownerData = owners[checkAccounts[i]] || [];
      const erc721Balance = await ethers.provider.getBalance(checkAccounts[i]);
      const umswapBalance = this.umswap != null ? await this.umswap.balanceOf(checkAccounts[i]) : 0;
      console.log("          " + this.padRight(this.getShortAccountName(checkAccounts[i]), 20) + " " + this.padLeft(ethers.utils.formatEther(erc721Balance), 24) + " " + this.padLeft(ethers.utils.formatEther(umswapBalance), 23) + " " + this.padRight(JSON.stringify(ownerData), 25));
    }
    console.log();

    if (this.umswapFactory != null) {
      const getUmswapsLength = await this.umswapFactory.getUmswapsLength();
      let indices = generateRange(0, getUmswapsLength - 1, 1);
      const getUmswaps = await this.umswapFactory.getUmswaps(this.user0, indices);
      // console.log("getUmswaps: " + JSON.stringify(getUmswaps, null, 2));
      console.log("            # Address              Creator              Symbol   Name                           ERC-721 Collection     User0 Balance     TotalSupply   In  Out  Rts  Rt# Aprv TokenIds                      ");
      console.log("          --- -------------------- -------------------- -------- ------------------------------ -------------------- --------------- --------------- ---- ---- ---- ---- ---- ------------------------------");
      for (let i = 0; i < getUmswaps[0].length; i++) {
        const stats = getUmswaps[7][i];
        // console.log("stats: " + JSON.stringify(stats, null, 2));
        // console.log("stats[0]: " + stats[0]);
        const ratingsLength = stats[5];
        console.log("          " + this.padLeft(i, 3) + " " + this.padRight(this.getShortAccountName(getUmswaps[0][i]), 20) + " " +
          this.padRight(this.getShortAccountName(getUmswaps[6][i]), 20) + " " + getUmswaps[1][i] + " " +
          this.padRight(getUmswaps[2][i], 30) + " " +
          this.padRight(this.getShortAccountName(getUmswaps[3][i]), 20) + " " +
          this.padLeft(ethers.utils.formatEther(stats[3]), 15) + " " +
          this.padLeft(ethers.utils.formatEther(stats[4]), 15) + " " +
          this.padLeft(stats[0], 4) + " " +
          this.padLeft(stats[1], 4) + " " +
          this.padLeft(stats[2], 4) + " " +
          this.padLeft(ratingsLength, 4) + " " +
          this.padLeft(stats[6], 4) + " " +
          this.padRight(JSON.stringify(getUmswaps[4][i].map((x) => { return parseInt(x.toString()); })) + "/" + JSON.stringify(getUmswaps[5][i].map((x) => { return parseInt(x.toString()); })), 30)
        );
        if (ratingsLength > 0 && i == 0 && this.umswap != null) {
          console.log();
          const indices = generateRange(0, ratingsLength - 1, 1);
          const ratings = await this.umswap.getRatings(indices);
          for (let j = 0; j < ratings.length; j++) {
            console.log("          " + this.getShortAccountName(ratings[j][0], 20) + " rated " + ratings[j][1]);
          }
        }
      }
      console.log();
    }

    if (false) {
    if (this.nix != null) {
      const tokensLength = (await this.nix.getLengths())[0];
      if (tokensLength > 0) {
        var tokensIndices = [...Array(parseInt(tokensLength)).keys()];
        const tokens = await this.nixHelper.getTokens(tokensIndices);
        for (let i = 0; i < tokens[0].length; i++) {
          const token = tokens[0][i];
          const ordersLength = tokens[1][i];
          const executed = tokens[2][i];
          const volumeToken = tokens[3][i];
          const volumeWeth = tokens[4][i];
          console.log("          Orders for " + this.getShortAccountName(token) + ", ordersLength: " + ordersLength + ", executed: " + executed + ", volumeToken: " + volumeToken + ", volumeWeth: " + ethers.utils.formatEther(volumeWeth));
          console.log("              # Maker          Taker                         Price B/S  Any/All Expiry                   Tx Count   Tx Max  RoyFac% Status               TokenIds");
          console.log("            --- -------------- -------------- -------------------- ---- ------- ------------------------ -------- -------- -------- -------------------- -----------------------");
          var orderIndices = [...Array(parseInt(ordersLength)).keys()];
          const orders = await this.nixHelper.getOrders(token, orderIndices);
          for (let i = 0; i < ordersLength; i++) {
            const maker = orders[0][i];
            const taker = orders[1][i];
            const tokenIds = orders[2][i];
            const price = orders[3][i];
            const data = orders[4][i];
            const buyOrSell = data[0];
            const anyOrAll = data[1];
            const expiry = data[2];
            const expiryString = expiry == 0 ? "(none)" : new Date(expiry * 1000).toISOString();
            const tradeCount = data[3];
            const tradeMax = data[4];
            const royaltyFactor = data[5];
            const orderStatus = data[6];
            const orderStatusString = ORDERSTATUSSTRING[orderStatus];
            console.log("            " + this.padLeft(i, 3) + " " +
              this.padRight(this.getShortAccountName(maker), 14) + " " +
              this.padRight(this.getShortAccountName(taker), 14) + " " +
              this.padLeft(ethers.utils.formatEther(price), 20) + " " +
              this.padRight(BUYORSELLSTRING[buyOrSell], 4) + " " +
              this.padRight(ANYORALLSTRING[anyOrAll], 7) + " " +
              this.padRight(expiryString, 24) + " " +
              this.padLeft(tradeCount.toString(), 8) + " " +
              this.padLeft(tradeMax.toString(), 8) + " " +
              this.padLeft(royaltyFactor.toString(), 8) + " " +
              this.padRight(orderStatusString.toString(), 20) + " " +
              JSON.stringify(tokenIds.map((x) => { return parseInt(x.toString()); })));
          }
          console.log();
        }
      }
    }

    const tradesLength = (await this.nix.getLengths())[1];
    if (tradesLength > 0) {
      console.log("          tradesLength: " + tradesLength);
      // if (ordersLength > 0) {
      //   console.log("            # Maker         Taker        Token                       Price Type     Expiry                   Tx Count   Tx Max Status               Key        TokenIds");
      //   console.log("          --- ------------- ------------ ------------ -------------------- -------- ------------------------ -------- -------- -------------------- ---------- -----------------------");
      const tradeIndices = [...Array(parseInt(tradesLength)).keys()];
      const trades = await this.nixHelper.getTrades(tradeIndices);
      console.log("          trades: " + JSON.stringify(trades.map((x) => { return x.toString(); })));
      // //   const orders = await this.nix.getOrders(tradeIndices);
      //
      //
      //   for (let i = 0; i < tradesLength; i++) {
      //     console.log("trade: " + JSON.stringify(trade));
      //   }
      // }
    }
  }
  }
}

const generateRange = (start, stop, step) => Array.from({ length: (stop - start) / step + 1}, (_, i) => start + (i * step));

/* Exporting the module */
module.exports = {
    ZERO_ADDRESS,
    BUYORSELL,
    ANYORALL,
    BUYORSELLSTRING,
    ANYORALLSTRING,
    Data,
    generateRange
}
