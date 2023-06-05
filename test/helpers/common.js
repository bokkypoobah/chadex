const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const PAIRKEY_NULL = "0x0000000000000000000000000000000000000000000000000000000000000000";
const ORDERKEY_SENTINEL = "0x0000000000000000000000000000000000000000000000000000000000000000";
const PRICE_EMPTY = 0;
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

    this.token0 = null;
    this.token1 = null;
    this.weth = null;
    this.decimals0 = null;
    this.decimals1 = null;
    this.decimalsWeth = null;
    this.decimals = {};

    this.chadex = null;

    this.gasPrice = ethers.utils.parseUnits("40", "gwei");
    this.ethUsd = ethers.utils.parseUnits("2000.00", 18);

    this.verbose = false;
  }

  async init() {
    [this.deployerSigner, this.user0Signer, this.user1Signer, this.user2Signer, this.user3Signer, this.feeAccountSigner, this.uiFeeAccountSigner] = await ethers.getSigners();
    [this.deployer, this.user0, this.user1, this.user2, this.user3, this.feeAccount, this.uiFeeAccount] = await Promise.all([this.deployerSigner.getAddress(), this.user0Signer.getAddress(), this.user1Signer.getAddress(), this.user2Signer.getAddress(), this.user3Signer.getAddress(), this.feeAccountSigner.getAddress(), this.uiFeeAccountSigner.getAddress()]);

    this.addAccount(ZERO_ADDRESS, "null");
    this.addAccount(this.deployer, "deployer");
    this.addAccount(this.user0, "user0");
    this.addAccount(this.user1, "user1");
    this.addAccount(this.user2, "user2");
    this.addAccount(this.user3, "user3");
    // this.addAccount(this.feeAccount, "feeAccount");
    // this.addAccount(this.uiFeeAccount, "uiFeeAccount");
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
            } else if (a.type == 'uint256' || a.type == 'uint128' || a.type == 'uint64') {
              if (a.name == 'tokens') {
                const decimals = this.decimals[log.address] || 18;
                result = result + ethers.utils.formatUnits(data.args[a.name], decimals);
              } else if (a.name.substring(0, 10) == 'baseTokens') {
                const decimals = this.decimals[this.token0.address] || 18;
                result = result + ethers.utils.formatUnits(data.args[a.name], decimals);
              } else if (a.name.substring(0, 11) == 'quoteTokens') {
                const decimals = this.decimals[this.weth.address] || 18;
                result = result + ethers.utils.formatUnits(data.args[a.name], decimals);
              } else if (a.name == 'wad' || a.name == 'amount' || a.name == 'balance' || a.name == 'value') {
                result = result + ethers.utils.formatUnits(data.args[a.name], 18);
              } else if (a.name == 'price') {
                result = result + ethers.utils.formatUnits(data.args[a.name], 12);
              } else {
                result = result + data.args[a.name].toString();
              }
            } else if (a.type == 'bytes32') {
              // result = result + data.args[a.name].substring(0, 6) + "..." + data.args[a.name].substring(62);
              result = result + data.args[a.name].substring(0, 10);
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

  async setToken0(token) {
    this.token0 = token;
    this.decimals0 = await this.token0.decimals();
    this.decimals[token.address] = this.decimals0;
    this.addContract(token, "Token0");
  }
  async setToken1(token) {
    this.token1 = token;
    this.decimals1 = await this.token1.decimals();
    this.decimals[token.address] = this.decimals1;
    this.addContract(token, "Token1");
  }
  async setWeth(weth) {
    this.weth = weth;
    this.decimalsWeth = await this.weth.decimals();
    this.decimals[weth.address] = this.decimalsWeth;
    this.addContract(weth, "WETH");
  }
  async setChadex(chadex) {
    this.chadex = chadex;
    this.addContract(chadex, "Chadex");
  }

  async getChadexData() {
    const pairs = {};
    let now = new Date();
    let row = 0;
    const pairsLength = parseInt(await this.chadex.pairsLength());
    for (let j = 0; j < pairsLength; j++) {
      const info = await this.chadex.pair(j);
      // console.log("info: " + JSON.stringify(info));
      const [pairKey, baseToken, quoteToken, factors] = info;
      const baseDecimals = this.decimals[baseToken];
      const quoteDecimals = this.decimals[quoteToken];
      const orders = {};
      for (let buySell = 0; buySell < 2; buySell++) {
        let price = PRICE_EMPTY;
        let firstOrderKey = ORDERKEY_SENTINEL;
        const ORDERSIZE = 4;
        orders[buySell] = [];
        let results = await this.chadex.getOrders(pairKey, buySell, ORDERSIZE, price, firstOrderKey);
        // console.log("results: " + JSON.stringify(results, null, 2));
        while (parseInt(results[0][0]) != 0) {

          for (let k = 0; k < results.length && parseInt(results[k][0]) != 0; k++) {
            // console.log("results[" + k + "]: " + JSON.stringify(results[k], null, 2));
            orders[buySell].push({ price: parseInt(results[k][0]), orderKey: results[k][1], nextOrderKey: results[k][2], maker: results[k][3], expiry: parseInt(results[k][4]), baseTokens: results[k][5].toString(), baseTokensFilled: results[k][6].toString() })
            price = results[k][0];
            firstOrderKey = results[k][2];
          }
          results = await this.chadex.getOrders(pairKey, buySell, ORDERSIZE, price, firstOrderKey);
        }
      }
      pairs[pairKey] = { baseToken, quoteToken, factors, baseDecimals, quoteDecimals, orders };
    }
    return pairs;
  }

  async printState(prefix) {
    console.log("\n        --- " + prefix + " ---");
    console.log("          Account                                   ETH " + this.padLeft(await this.token0.symbol() + "[" + this.decimals0 + "]", 24) + " " + this.padLeft(await this.token1.symbol() + "[" + this.decimals1 + "]", 24) + " " + this.padLeft(await this.weth.symbol() + "[" + this.decimalsWeth + "]", 24) + " Blah");
    console.log("          -------------------- ------------------------ ------------------------ ------------------------ ------------------------ ---------------------------------------------");
    const checkAccounts = [this.deployer, this.user0, this.user1, this.user2, this.user3/*, this.feeAccount, this.uiFeeAccount*/];
    if (this.chadex) {
      checkAccounts.push(this.chadex.address);
    }
    for (let i = 0; i < checkAccounts.length; i++) {
      const balance = await ethers.provider.getBalance(checkAccounts[i]);
      const token0Balance = this.token0 == null ? 0 : await this.token0.balanceOf(checkAccounts[i]);
      const token1Balance = this.token1 == null ? 0 : await this.token1.balanceOf(checkAccounts[i]);
      const wethBalance = this.weth == null ? 0 : await this.weth.balanceOf(checkAccounts[i]);
      console.log("          " + this.padRight(this.getShortAccountName(checkAccounts[i]), 20) + " " + this.padLeft(ethers.utils.formatEther(balance), 24) + " " + this.padLeft(ethers.utils.formatUnits(token0Balance, this.decimals0), 24) + " " + this.padLeft(ethers.utils.formatUnits(token1Balance, this.decimals1), 24) + " " + this.padLeft(ethers.utils.formatUnits(wethBalance, this.decimalsWeth), 24));
    }
    console.log();

    if (this.chadex) {
      const pairsLength = parseInt(await this.chadex.pairsLength());
      console.log("          Chadex: " + this.getShortAccountName(this.chadex.address));
      const pairInfos = [];
      for (let j = 0; j < pairsLength; j++) {
        const info = await this.chadex.pair(j);
        // console.log("info: " + JSON.stringify(info));
        pairInfos.push({ pairKey: info[0], baseToken: info[1], quoteToken: info[2], factors: info[3] })
      }

      let now = new Date();
      let row = 0;
      for (let j = 0; j < pairInfos.length; j++) {
        const pair = pairInfos[j];
        console.log("          ----- Pair " + pair.pairKey + " " + this.getShortAccountName(pair.baseToken) + "/" + this.getShortAccountName(pair.quoteToken) + " " + pair.factors[0] + " " + pair.factors[1] + " -----");
        for (let buySell = 0; buySell < 2; buySell++) {
          console.log("              #     " + (buySell == 0 ? " BUY" : "SELL") +" Price OrderKey   Next       Maker         Expiry(s)                Tokens     Total Available Base    Total Available Quote")
          console.log("            --- -------------- ---------- ---------- ------------ ---------- --------------------- ------------------------ ------------------------");

          let price = PRICE_EMPTY;
          let firstOrderKey = ORDERKEY_SENTINEL;
          const ORDERSIZE = 5;
          const baseDecimals = this.decimals[pair.baseToken];
          const quoteDecimals = this.decimals[pair.quoteToken];
          let results = await this.chadex.getOrders(pair.pairKey, buySell, ORDERSIZE, price, firstOrderKey);
          while (parseInt(results[0][0]) != 0) {
            // console.log("            * --- Start price: " + price + ", firstOrderKey: " + firstOrderKey + " ---")
            for (let k = 0; k < results.length && parseInt(results[k][0]) != 0; k++) {
              const orderInfo = results[k];
              const [price1, orderKey, nextOrderKey, maker, expiry, tokens, availableBase, availableQuote] = orderInfo;
              var minutes = (expiry - now / 1000) / 60;
              console.log("              " + (row++) + " " +
                this.padLeft(ethers.utils.formatUnits(price1, 12), 14) + " " +
                orderKey.substring(0, 10) + " " +
                nextOrderKey.substring(0, 10) + " " +
                this.getShortAccountName(maker) + " " +
                this.padLeft(minutes.toFixed(2), 10) + " " +
                this.padLeft(ethers.utils.formatUnits(tokens, baseDecimals), 21) + " " +
                this.padLeft(ethers.utils.formatUnits(availableBase, baseDecimals), 24) + " " +
                this.padLeft(ethers.utils.formatUnits(availableQuote, quoteDecimals), 24)
            );
              price = results[k][0];
              firstOrderKey = results[k][2];
            }
            // console.log("            * --- End price: " + price + ", firstOrderKey: " + firstOrderKey + " ---")
            results = await this.chadex.getOrders(pair.pairKey, buySell, ORDERSIZE, price, firstOrderKey);
          }
          console.log();

          price = await this.chadex.getBestPrice(pair.pairKey, buySell);
          while (price != 0) {
            var orderQueue = await this.chadex.getOrderQueue(pair.pairKey, buySell, price);
            console.log("            price: " + ethers.utils.formatUnits(price, 12) + " head=" + orderQueue[0].substring(0, 10) + " tail=" + orderQueue[1].substring(0, 10));
            let orderKey = orderQueue[0];
            while (orderKey != 0) {
              let order = await this.chadex.getOrder(orderKey);
              var minutes = (order[2] - new Date() / 1000) / 60;
              console.log("              Order key=" + orderKey.substring(0, 10) + " next=" + order[0].substring(0, 10) +
                " maker=" + this.getShortAccountName(order[1]) +
                " expiry=" + minutes.toFixed(2) + "s tokens=" + ethers.utils.formatUnits(order[3], pair.baseDecimals));
              orderKey = order[0];
            }
            price = await this.chadex.getNextBestPrice(pair.pairKey, buySell, price);
          }
          console.log();
        }

        // struct TradeEvent {
        //     OrderKey orderKey;
        //     Account taker; // address
        //     Account maker; // address
        //     BuySell buySell; // uint8
        //     Price price; // uint128
        //     Tokens filled; // int128
        //     Tokens quoteFilled; // int128
        //     uint48 blockNumber; // 2^48 = 281,474,976,710,656
        //     uint48 timestamp; // 2^48 = 281,474,976,710,656
        // }
        // console.log("              # Block  Timestamp Pair Key   Order Key  Taker        Maker        B/S            Price                Filled   Quote Tokens Filled")
        // console.log("            --- ----- ---------- ---------- ---------- ------------ ------------ ---- --------------- --------------------- ---------------------");
        console.log("              # Block  Timestamp Taker        B/S            Price                   Filled      Quote Tokens Filled")
        console.log("            --- ----- ---------- ------------ ---- --------------- ------------------------ ------------------------");
        const tradeLength = await this.chadex.tradesLength(pair.pairKey);
        const tradeEvents = await this.chadex.getTradeEvents(pair.pairKey, parseInt(tradeLength) + 1, 0); // Adding 1 to show empty record at end
        for (let i = 0; i < tradeEvents.length && tradeEvents[i][0] != 0; i++) {
          const [/*pairKey, orderKey, */taker, /*maker, */buySell, price, filled, quoteFilled, blockNumber, timestamp] = tradeEvents[i];
          // var minutes = (timestamp - (now / 1000)) / 60;
          console.log("              " + i + " " + this.padLeft(blockNumber, 5) + " " + timestamp + " " +
            // pairKey.substring(0, 10) + " " +
            // orderKey.substring(0, 10) + " " +
            this.getShortAccountName(taker) + " " +
            // this.getShortAccountName(maker) + " " +
            (buySell == 1 ? "Buy  " : "Sell ") + " " +
            this.padLeft(ethers.utils.formatUnits(price, 12), 14) + " " +
            this.padLeft(ethers.utils.formatUnits(filled, 18), 24) + " " +
            this.padLeft(ethers.utils.formatUnits(quoteFilled, 18), 24));
          // console.log("            blockNumber: " + blockNumber + ", timestamp=" + timestamp + ", pairKey=" + pairKey + ", taker=" + taker +
          //   ", buySell=" + buySell + ", price=" + ethers.utils.formatUnits(price, 12) + ", filled=" + ethers.utils.formatUnits(filled, 18) + ", quoteFilled=" + ethers.utils.formatUnits(quoteFilled, 18));
        }
        console.log();

      }


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
      //     BestOrderResult bestBuyOrder;
      //     BestOrderResult bestSellOrder;
      // }
      const pairs = await this.chadex.getPairs(2, 0);
      for (let i = 0; i < pairs.length && pairs[i][0] != 0; i++) {
        const [pairKey, base, quote, factors, bestBuyOrder, bestSellOrder] = pairs[i];
        console.log("            pairKey: " + pairKey + ", base=" + JSON.stringify(base) + ", quote=" + JSON.stringify(quote) +
          ", factors=" + factors +
          ", bestBuyOrder=" + JSON.stringify(bestBuyOrder) + ", bestSellOrder=" + JSON.stringify(bestSellOrder));
      }
      console.log();
    }
  }
}

const generateRange = (start, stop, step) => Array.from({ length: (stop - start) / step + 1}, (_, i) => start + (i * step));

/* Exporting the module */
module.exports = {
    ZERO_ADDRESS,
    PAIRKEY_NULL,
    ORDERKEY_SENTINEL,
    PRICE_EMPTY,
    BUYORSELL,
    ANYORALL,
    BUYORSELLSTRING,
    ANYORALLSTRING,
    Data,
    generateRange
}
