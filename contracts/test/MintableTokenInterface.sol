pragma solidity ^0.8.0;

import "../ERC20.sol";


// ----------------------------------------------------------------------------
// MintableToken Interface = ERC20 + symbol + name + decimals + mint + burn
// + approveAndCall
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
interface MintableTokenInterface is ERC20 {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
    function approveAndCall(address spender, uint tokens, bytes memory data) external returns (bool success);
    function mint(address tokenOwner, uint tokens) external returns (bool success);
    function burn(address tokenOwner, uint tokens) external returns (bool success);
}
// ----------------------------------------------------------------------------
// End - MintableToken Interface
// ----------------------------------------------------------------------------
