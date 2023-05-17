pragma solidity ^0.8.0;

// ----------------------------------------------------------------------------
// ApproveAndCall Fallback
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
interface ApproveAndCallFallback {
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) external;
}
// ----------------------------------------------------------------------------
// End - ApproveAndCall Fallback
// ----------------------------------------------------------------------------
