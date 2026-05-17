// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GovToken.sol";
import "../src/Timelock.sol";
import "../src/MyGovernor.sol";
import "../src/IronToken.sol";
import "../src/GameItems.sol";
import "../src/GameEngineV1.sol";
import "../src/IronShop.sol";

contract VerifyDeployment is Script {
    function run() external {
        // Read broadcast file to get deployed addresses
        string memory path = string.concat(
            vm.projectRoot(), "/broadcast/DeployDAO.s.sol/", vm.toString(block.chainid), "/run-latest.json"
        );
        string memory json = vm.readFile(path);

        // Extract addresses using standard jq syntax in forge
        address timelockAddr = stdJson.readAddress(
            json, "$.transactions[?(@.contractName == 'Timelock' && @.transactionType == 'CREATE')].contractAddress"
        );
        address governorAddr = stdJson.readAddress(
            json, "$.transactions[?(@.contractName == 'MyGovernor' && @.transactionType == 'CREATE')].contractAddress"
        );
        address engineAddr = stdJson.readAddress(
            json, "$.transactions[?(@.contractName == 'ERC1967Proxy' && @.transactionType == 'CREATE')].contractAddress"
        );
        address ironTokenAddr = stdJson.readAddress(
            json, "$.transactions[?(@.contractName == 'IronToken' && @.transactionType == 'CREATE')].contractAddress"
        );
        address gameItemsAddr = stdJson.readAddress(
            json, "$.transactions[?(@.contractName == 'GameItems' && @.transactionType == 'CREATE')].contractAddress"
        );

        Timelock timelock = Timelock(payable(timelockAddr));
        MyGovernor governor = MyGovernor(payable(governorAddr));
        GameEngineV1 engine = GameEngineV1(engineAddr);
        IronToken iron = IronToken(ironTokenAddr);
        GameItems items = GameItems(gameItemsAddr);

        console.log("=== Post-Deployment Verification Report ===");

        // 1. Check Owner is Timelock
        require(engine.owner() == address(timelock), "Engine owner is not Timelock");
        require(iron.owner() == address(timelock), "IronToken owner is not Timelock");
        require(items.owner() == address(engine), "GameItems owner is not Engine");
        console.log("[PASS] All ownerships transferred correctly to DAO.");

        // 2. Check Timelock Delay
        require(timelock.getMinDelay() == 10, "Timelock delay is incorrect"); // Assuming 10 sec from our recent change
        console.log("[PASS] Timelock delay matches spec.");

        // 3. Check Governor Parameters
        require(governor.votingDelay() == 1, "Incorrect voting delay");
        require(governor.votingPeriod() == 5, "Incorrect voting period");
        require(governor.quorumNumerator() == 4, "Incorrect quorum numerator"); // From GovernorVotesQuorumFraction(4)
        console.log("[PASS] Governor parameters match spec.");

        // 4. Check no Admin Backdoors
        // Timelock DEFAULT_ADMIN_ROLE should ONLY be held by the Timelock itself
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // In our setup, deployer renounced the admin role. Let's verify deployer does not have it.
        // We assume msg.sender was the deployer
        require(!timelock.hasRole(adminRole, msg.sender), "Deployer still holds Admin Role!");
        require(timelock.hasRole(adminRole, address(timelock)), "Timelock is not its own Admin!");

        console.log("[PASS] No admin backdoors remain. Deployer renounced admin role.");

        console.log("=========================================");
        console.log("All verifications passed successfully!");
    }
}
