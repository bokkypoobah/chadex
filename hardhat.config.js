require("@nomiclabs/hardhat-ethers");

/* require("@nomicfoundation/hardhat-toolbox"); */

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: false,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  // defaultNetwork: "hardhat",
  // networks: {
  //     hardhat: {
  //         blockGasLimit: 30_000_000,
  //     },
  // },
};
