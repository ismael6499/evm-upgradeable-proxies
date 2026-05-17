// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title EIP-1967 Storage Slot Constants
/// @author Agustin Acosta
/// @notice Defines standardized storage slots for UUPS proxy implementations and admin ownership
library ProxyStorageSlots {
    /// @dev Storage slot for implementation address: bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    /// @dev Storage slot for proxy owner address: bytes32(uint256(keccak256("eip1967.proxy.owner")) - 1)
    bytes32 internal constant OWNER_SLOT = 0xb53592574704f51e605401155056259f3239c057697479700346a588b3940089;
}

/// @title UUPS Upgradeable Vault - Version 1 (Core Deposit Accounting)
/// @author Agustin Acosta
/// @notice Implements UUPS proxy upgrade mechanics and initial deposit vault state
/// @dev Implements storage slot alignment and authorization guards to prevent storage collisions
contract VaultV1 {
    // --- Storage Layout (MUST NOT BE REORDERED IN FUTURE UPGRADES) ---
    address public owner;
    bool private initialized;
    uint256 public totalDeposits;
    mapping(address => uint256) public balances;

    // --- Custom Errors ---
    error AlreadyInitialized();
    error UnauthorizedOwner();
    error ZeroDepositAmount();
    error InsufficientBalance();
    error InvalidImplementationAddress();

    // --- Events ---
    event Initialized(address indexed owner);
    event Deposit(address indexed user, uint256 amount);
    event Upgraded(address indexed newImplementation);

    /// @notice Locks the constructor to prevent uninitialized implementation contract hijacking
    constructor() {
        initialized = true;
    }

    /// @notice Initializes the proxy contract state on deployment
    /// @param _owner Target owner address authorized for protocol administration
    function initialize(address _owner) external {
        if (initialized) revert AlreadyInitialized();
        if (_owner == address(0)) revert UnauthorizedOwner();

        owner = _owner;
        initialized = true;

        emit Initialized(_owner);
    }

    /// @notice Deposit native ETH into the vault accounting
    function deposit() external payable {
        if (msg.value == 0) revert ZeroDepositAmount();

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Upgrades the implementation logic address (UUPS Pattern)
    /// @param _newImplementation Address of the newly deployed logic contract
    function upgradeTo(address _newImplementation) external {
        if (msg.sender != owner) revert UnauthorizedOwner();
        if (_newImplementation == address(0) || _newImplementation.code.length == 0) {
            revert InvalidImplementationAddress();
        }

        // Store new implementation address in EIP-1967 slot
        bytes32 slot = ProxyStorageSlots.IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, _newImplementation)
        }

        emit Upgraded(_newImplementation);
    }

    /// @notice Returns the protocol version identifier
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
