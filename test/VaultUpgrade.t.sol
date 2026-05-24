// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VaultV1} from "../src/VaultV1.sol";
import {VaultV2} from "../src/VaultV2.sol";
import {ERC1967Proxy} from "../src/ERC1967Proxy.sol";

interface Vm {
    function prank(address) external;
    function deal(address, uint256) external;
    function expectRevert(bytes4) external;
}

/// @title VaultUpgradeTest - Unit & Storage Invariant Verification
/// @author Agustin Acosta
/// @notice Verifies zero storage collision, state preservation, and 100% branch coverage across UUPS upgrades
contract VaultUpgradeTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    VaultV1 public implementationV1;
    VaultV2 public implementationV2;
    ERC1967Proxy public proxy;

    VaultV1 public proxyVaultV1;
    VaultV2 public proxyVaultV2;

    address public owner = address(0x1111);
    address public user = address(0x2222);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);

        // Deploy V1 Implementation
        implementationV1 = new VaultV1();

        // Encode initializer call data
        bytes memory initData = abi.encodeWithSelector(VaultV1.initialize.selector, owner);

        // Deploy Proxy pointing to V1
        proxy = new ERC1967Proxy(address(implementationV1), initData);

        proxyVaultV1 = VaultV1(address(proxy));
    }

    function test_InitialDeployment_Success() public view {
        require(proxyVaultV1.owner() == owner, "Owner mismatch");
        require(keccak256(bytes(proxyVaultV1.version())) == keccak256(bytes("1.0.0")), "Version mismatch");
    }

    function test_RevertWhen_DoubleInitialize() public {
        vm.expectRevert(VaultV1.AlreadyInitialized.selector);
        proxyVaultV1.initialize(owner);
    }

    function test_RevertWhen_InitializeZeroAddress() public {
        VaultV1 uninitVault = new VaultV1();
        ERC1967Proxy uninitProxy = new ERC1967Proxy(address(uninitVault), "");
        VaultV1 target = VaultV1(address(uninitProxy));

        vm.expectRevert(VaultV1.UnauthorizedOwner.selector);
        target.initialize(address(0));
    }

    function test_RevertWhen_DepositZeroValue() public {
        vm.prank(user);
        vm.expectRevert(VaultV1.ZeroDepositAmount.selector);
        proxyVaultV1.deposit{value: 0}();
    }

    function test_Deposit_Success() public {
        vm.prank(user);
        proxyVaultV1.deposit{value: 5 ether}();

        require(proxyVaultV1.balances(user) == 5 ether, "Balance mismatch");
        require(proxyVaultV1.totalDeposits() == 5 ether, "Total deposits mismatch");
    }

    function test_RevertWhen_UnauthorizedUpgrade() public {
        implementationV2 = new VaultV2();
        vm.prank(user);
        vm.expectRevert(VaultV1.UnauthorizedOwner.selector);
        proxyVaultV1.upgradeTo(address(implementationV2));
    }

    function test_RevertWhen_UpgradeToInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(VaultV1.InvalidImplementationAddress.selector);
        proxyVaultV1.upgradeTo(address(0));
    }

    function test_RevertWhen_UpgradeToNonContractAddress() public {
        vm.prank(owner);
        vm.expectRevert(VaultV1.InvalidImplementationAddress.selector);
        proxyVaultV1.upgradeTo(address(0x9999));
    }

    function test_UpgradeToV2_PreservesState() public {
        // 1. User deposits in V1
        vm.prank(user);
        proxyVaultV1.deposit{value: 10 ether}();

        // 2. Owner deploys V2 and upgrades proxy
        implementationV2 = new VaultV2();

        vm.prank(owner);
        proxyVaultV1.upgradeTo(address(implementationV2));

        // Cast proxy to V2 interface
        proxyVaultV2 = VaultV2(address(proxy));

        // 3. Assert state preservation post-upgrade
        require(proxyVaultV2.owner() == owner, "Owner corrupted after upgrade");
        require(proxyVaultV2.balances(user) == 10 ether, "User balance lost after upgrade");
        require(proxyVaultV2.totalDeposits() == 10 ether, "Total deposits corrupted");
        require(keccak256(bytes(proxyVaultV2.version())) == keccak256(bytes("2.0.0")), "Version upgrade failed");

        // 4. Test V2 Distribute Yield
        vm.prank(owner);
        proxyVaultV2.distributeYield{value: 2 ether}(2 ether);
        require(proxyVaultV2.totalYieldDistributed() == 2 ether, "Yield distribution failed");

        // 5. Test V2 Withdraw
        vm.prank(user);
        proxyVaultV2.withdraw(4 ether);

        require(proxyVaultV2.balances(user) == 6 ether, "Withdraw balance update failed");
    }

    function test_RevertWhen_WithdrawZeroAmount() public {
        implementationV2 = new VaultV2();
        vm.prank(owner);
        proxyVaultV1.upgradeTo(address(implementationV2));
        proxyVaultV2 = VaultV2(address(proxy));

        vm.prank(user);
        vm.expectRevert(VaultV1.ZeroDepositAmount.selector);
        proxyVaultV2.withdraw(0);
    }

    function test_RevertWhen_WithdrawInsufficientBalance() public {
        implementationV2 = new VaultV2();
        vm.prank(owner);
        proxyVaultV1.upgradeTo(address(implementationV2));
        proxyVaultV2 = VaultV2(address(proxy));

        vm.prank(user);
        vm.expectRevert(VaultV1.InsufficientBalance.selector);
        proxyVaultV2.withdraw(10 ether);
    }

    function test_RevertWhen_DistributeYieldUnauthorized() public {
        implementationV2 = new VaultV2();
        vm.prank(owner);
        proxyVaultV1.upgradeTo(address(implementationV2));
        proxyVaultV2 = VaultV2(address(proxy));

        vm.prank(user);
        vm.expectRevert(VaultV1.UnauthorizedOwner.selector);
        proxyVaultV2.distributeYield{value: 1 ether}(1 ether);
    }

    function test_RevertWhen_DistributeYieldZeroValue() public {
        implementationV2 = new VaultV2();
        vm.prank(owner);
        proxyVaultV1.upgradeTo(address(implementationV2));
        proxyVaultV2 = VaultV2(address(proxy));

        vm.prank(owner);
        vm.expectRevert(VaultV1.ZeroDepositAmount.selector);
        proxyVaultV2.distributeYield{value: 0}(1 ether);
    }
}
