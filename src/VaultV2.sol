// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VaultV1} from "./VaultV1.sol";

/// @title UUPS Upgradeable Vault - Version 2 (Withdrawals & Yield Distribution)
/// @author Agustin Acosta
/// @notice Extends VaultV1 logic with withdrawal capabilities while maintaining 100% storage slot alignment
/// @dev Appends new storage variables STRICTLY AFTER existing V1 storage layout to prevent storage collisions
contract VaultV2 is VaultV1 {
    // --- New Storage Slot (Appended to V1 Layout) ---
    uint256 public totalYieldDistributed;

    // --- New Events ---
    event Withdraw(address indexed user, uint256 amount);
    event YieldDistributed(uint256 totalAmount);

    /// @notice Withdraws stored ETH from the vault
    /// @param _amount Quantity of Wei to withdraw
    function withdraw(uint256 _amount) external {
        if (_amount == 0) revert ZeroDepositAmount();
        if (balances[msg.sender] < _amount) revert InsufficientBalance();

        balances[msg.sender] -= _amount;
        totalDeposits -= _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert InsufficientBalance();

        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Simulates yield distribution to active pool accounts
    /// @param _yieldAmount Total yield added to vault balance
    function distributeYield(uint256 _yieldAmount) external payable {
        if (msg.sender != owner) revert UnauthorizedOwner();
        if (msg.value != _yieldAmount) revert ZeroDepositAmount();

        totalYieldDistributed += _yieldAmount;
        totalDeposits += _yieldAmount;

        emit YieldDistributed(_yieldAmount);
    }

    /// @notice Returns the protocol version identifier
    function version() external pure override returns (string memory) {
        return "2.0.0";
    }
}
