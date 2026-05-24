# 🔄 EVM Upgradeability & Proxy Architecture (UUPS vs Transparent)

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?style=flat-square&logo=solidity)
![EVM](https://img.shields.io/badge/EVM-Storage_Layout-363636?style=flat-square)
![Foundry](https://img.shields.io/badge/Foundry-Testing-363636?style=flat-square&logo=foundry)
![Security](https://img.shields.io/badge/EIP--1967-Slots-363636?style=flat-square)

A reference implementation of upgradeable smart contract architecture on the Ethereum Virtual Machine (EVM), focusing on **Universal Upgradeable Proxy Standard (UUPS / EIP-1822)**, **EIP-1967 Storage Slots**, and **Storage Collision Mitigation**.

---

## 📌 Context vs. Implementation

### 1. Traditional Software Deployment vs. EVM Immutability
* **Traditional Backend (Java/Spring):** Updating service logic involves pushing a new container deployment via CI/CD. Memory layout and database schemas evolve dynamically.
* **EVM Smart Contracts:** Deployed bytecode at an address is immutable. Upgradeability requires separating **State (Storage)** from **Logic (Bytecode execution)** using proxy delegation.

### 2. Execution Delegation (`delegatecall`)
When a user calls the Proxy contract, the Proxy executes a `delegatecall` to the Implementation logic contract:
* **Context:** Code is loaded from the Implementation address, but executed strictly inside the Proxy's storage, balance, and `msg.sender` context.
* **Storage Alignment:** Storage variable layout in `VaultV2` MUST strictly extend `VaultV1` storage layout without reordering existing slots to prevent catastrophic storage corruption.

```
+------------------+                    +-----------------------+
|  Proxy Contract  |  -- delegatecall ->| Implementation (V1/V2)|
| (Storage & ETH)  |                    |      (Pure Logic)     |
+------------------+                    +-----------------------+
```

---

## 🛠️ Technical Highlights

### EIP-1967 Storage Slot Isolation
To prevent collision between implementation logic variables and proxy internal state variables, implementation addresses are stored at fixed pseudo-random slots:
```solidity
// Implementation Slot: bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
```

### Initializer Lock Pattern
Constructors execute during contract creation but modify the storage of the Implementation contract itself, not the Proxy.
* `VaultV1` locks the constructor via `initialized = true` to prevent uninitialized implementation hijacking.
* Proxy storage is initialized via `initialize(address _owner)` upon deployment.

---

## 🧪 Testing & Verification

Executed unit testing and upgrade invariant verification via Foundry:

```bash
forge test -vvv
```

### Verified Test Vectors
1. `test_InitialDeployment_Success`: Verifies EIP-1967 proxy initialization and initial `V1` logic.
2. `test_Deposit_Success`: Validates state writing inside Proxy storage context.
3. `test_UpgradeToV2_PreservesState`: Upgrades logic pointer from `V1` to `V2`, verifying that user balances, ownership, and ETH totals remain 100% intact post-upgrade.
