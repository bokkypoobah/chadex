# DexOne
Dex One

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
* Move past consumed orders
* Handle canTransferFrom() - https://github.com/ethereum/EIPs/issues/1594
      function canTransferFrom(address _from, address _to, uint256 _value, bytes _data) external view returns (bool, byte, bytes32);
