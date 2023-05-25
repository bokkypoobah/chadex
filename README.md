# Dexz

Fully on-chain ERC-20/ERC-20 DEX using Red-Black Trees and queues for sorted orderbook executions.

Status: Work in progress

https://bokkypoobah.github.io/Dexz/

<br />

---

## Notes


npm install --save-dev @nomiclabs/hardhat-truffle5 @nomiclabs/hardhat-web3 web3

https://docs.openzeppelin.com/test-helpers/0.5/

npm install --save-dev @openzeppelin/test-helpers
npm install --save-dev solidity-coverage

npm install --save-dev @nomiclabs/hardhat-ethers 'ethers@^5.0.0'



**Coverage**

Run coverage reports using the command

`npx hardhat coverage`

Output will be in the generated coverage directory

If you are using yarn, you can run

`yarn hardhat coverage`


---

## Old Stuff

Token incompatibilities - [An Incompatibility in Ethereum Smart Contract Threatening dApp Ecosystem](https://medium.com/loopring-protocol/an-incompatibility-in-smart-contract-threatening-dapp-ecosystem-72b8ca5db4da)

* Token registry includes rating
  * 0 scam, 1 suspect, 2 unrated, 3 OK, 5 reputable
* Prevent front running



hash(ccy1/ccy2) => Orderbook

Orderbook
  RedBlackTree index by price
    buyOrders - Expiring Queue
      => Order
         * OrderType orderType;
         * address baseToken;      // GNT
         * address quoteToken;     // ETH
         * uint price;             // GNT/ETH = 0.00054087 = #quoteToken per unit baseToken
         * uint expiry;
         * uint amount;            // GNT - baseToken
    sellOrders


TODO:
* Move past consumed orders, graceful gas limit exit
* Handle canTransferFrom() - https://github.com/ethereum/EIPs/issues/1594
      `function canTransferFrom(address _from, address _to, uint256 _value, bytes _data) external view returns (bool, byte, bytes32);``

<br />

## Function Calls

### trade

```javascript
function trade(uint orderFlag, address baseToken, address quoteToken, uint price, uint expiry, uint baseTokens, address uiFeeAccount) public payable returns (uint _baseTokensFilled, uint _quoteTokensFilled, uint _baseTokensOnOrder, bytes32 _orderKey);
```

Parameters     | Notes
:------------- |:-------
`orderFlag`    | `uint256`
`baseToken`    | `address` of the baseToken
`quoteToken`   | `address` of the quoteToken
`price`        | `uint256`
`expiry`       | `uint256`
`baseTokens`   | `uint256`
`uiFeeAccount` | `address`

And `orderFlag` is constructed using the following bitmasks

```javascript
// Note that the BUY and SELL flags are used as indices
uint constant public ORDERTYPE_BUY = 0x00;
uint constant public ORDERTYPE_SELL = 0x01;
uint constant public ORDERFLAG_BUYSELL_MASK = 0x01;
// BK Default is to fill as much as possible
uint constant public ORDERFLAG_FILL = 0x00;
uint constant public ORDERFLAG_FILLALL_OR_REVERT = 0x10;
uint constant public ORDERFLAG_FILL_AND_ADD_ORDER = 0x20;
```
