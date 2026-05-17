# GameFi DAO Ecosystem - Architecture Document

## 1. Executive Summary
The GameFi DAO Ecosystem ("Aetheria") is a full-stack, decentralized protocol integrating complex DeFi, GameFi, and Governance components into a single synergistic economy. It is built using Solidity ^0.8.24 and deployed via the Foundry toolkit, leveraging the OpenZeppelin v5.1.0 library. This document outlines the architectural decisions, design patterns, and systemic workflows that power the platform.

## 2. Core Protocol Components

### 2.1 Governance Layer
The DAO utilizes a dual-contract architecture for secure and decentralized decision-making:
*   **GovToken (ERC20Votes & ERC20Permit):** The platform's governance token. It includes built-in snapshotting for voting power (ERC20Votes) and supports gasless approvals via EIP-2612 signatures (ERC20Permit). The `deployer` initially delegates to themselves to execute the initial setup, after which minting privileges are handed over to the DAO.
*   **TimelockController:** Acts as the treasury and the absolute owner of the entire smart contract ecosystem. All successful governance proposals must pass through a mandatory 2-day (172800 seconds) timelock delay before execution. This mitigates hostile takeovers and gives users time to exit if a malicious proposal passes.
*   **MyGovernor:** The execution engine for the DAO. It utilizes a 1-day voting delay, a 1-week voting period, a 1% proposal threshold, and a 4% quorum requirement. It is integrated directly with the Timelock via `GovernorTimelockControl`.

### 2.2 DeFi Layer
The decentralized finance components provide liquidity and yield to the ecosystem:
*   **IronToken (ERC20):** The primary base currency of the game. Minting is strictly controlled by the Timelock (DAO) or integrated peripheral contracts (like the IronShop).
*   **AMM (Constant Product Market Maker):** An `x * y = k` Automated Market Maker built from scratch. It facilitates permissionless swapping between `GovToken` and `IronToken` with a 0.3% swap fee. It implements standard LP token minting/burning and strict slippage protection parameters.
*   **AMMFactory:** A factory contract responsible for deploying new AMM pairs. It demonstrates advanced deployment techniques by offering both standard `CREATE` deployment and deterministic `CREATE2` deployment (via `createPoolDeterministic`).
*   **IronVault (ERC4626 Tokenized Vault):** A standard-compliant yield-bearing vault where users can stake their `IronToken` in exchange for `vIRON` shares. The DAO can inject yield programmatically via the `addYield` function.

### 2.3 GameFi Layer
The gaming mechanics are encapsulated in proxy-upgradeable logic:
*   **GameItems (ERC1155):** Manages the in-game assets: Part A (ID 1), Part B (ID 2), and the Legendary Sword (ID 3). It implements a `craftSword()` function that burns Parts A & B, deducts an `IronToken` fee, and mints the Legendary Sword.
*   **GameEngineV1 (UUPS Proxy):** The core game logic. It implements the `farmLoot` function utilizing highly gas-optimized inline Yul assembly for pseudo-random number generation. It is deployed behind an ERC1967 Proxy to allow the DAO to upgrade the game logic seamlessly in the future without disrupting the state.
*   **IronShop (Oracle Integration):** Allows users to purchase `IronToken` directly using native ETH. It utilizes a Chainlink `AggregatorV3Interface` to fetch the real-time ETH/USD price, complete with staleness checks to prevent sandwich attacks on outdated prices.

## 3. System Architecture & Ownership Hand-off
The protocol employs strict Access Control (Ownable) and structural hierarchies. The deployment script (`DeployDAO.s.sol`) guarantees that the deployment address is stripped of all privileges by the end of the script.

**Ownership Flow:**
1. `GameEngineV1` (Proxy) owns `GameItems` (can mint drops).
2. `Timelock` owns `IronToken`, `GameEngineV1`, and `IronShop`.
3. `MyGovernor` holds the PROPOSER and CANCELLER roles on the `Timelock`.

This ensures that *no single EOA* has control over the game economy post-deployment.

## 4. Key Design Patterns
*   **Proxy Pattern (UUPS):** Chosen over Transparent Proxy for gas efficiency. The upgrade logic resides in the implementation contract (`GameEngineV1`), protecting against proxy selector clashing.
*   **Checks-Effects-Interactions (CEI):** Strictly enforced across the AMM, Vault, and GameEngine to prevent reentrancy vulnerabilities.
*   **Oracle Abstraction:** The `IronShop` relies on the `AggregatorV3Interface`, allowing the system to use a mock oracle during testing and seamlessly switch to Chainlink on mainnet.
*   **Factory Pattern:** The `AMMFactory` encapsulates the logic for instantiating new exchange pools.

## 5. Gas Optimization Strategies
The protocol implements several gas-saving techniques:
1.  **Inline Yul Assembly:** Used in `GameEngineV1.farmLoot` for pseudo-random number generation. By utilizing the free memory pointer (`mload(0x40)`) to store operational variables instead of standard Solidity state hashing, the Yul implementation saves significant gas during high-loop iterations compared to the `farmLootPureSolidity` baseline.
2.  **Custom Errors:** Revert strings are utilized sparingly; future iterations can transition to custom errors for further deployment gas reduction.
3.  **Caching Storage Variables:** In the AMM, storage variables like `reserveA` and `reserveB` are cached in memory during swaps to minimize `SLOAD` operations.

## 6. Frontend Integration
The frontend is a lightweight, high-performance vanilla JavaScript application utilizing `ethers.js v5`. It implements a dynamic Glassmorphism aesthetic and features a modular tabbed interface (Dashboard, Inventory, Marketplace, Vault, Governance). It perfectly mirrors the smart contract requirements, such as enforcing a two-step `approve` → `deposit` UX flow for the Vault and Crafting mechanics.
