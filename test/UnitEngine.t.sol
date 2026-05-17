// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseSetup.t.sol";
import "../src/GameEngineV2.sol";

contract GameEngineTest is BaseSetup {
    function test_version() public view { assertEq(engine.version(), "1.0.0"); }
    function test_dropChance100() public view { assertEq(engine.dropChanceBps(), 10000); }
    function test_owner() public view { assertEq(engine.owner(), deployer); }

    function test_farmLoot() public {
        vm.prank(alice);
        engine.farmLoot(1);
        uint256 partA = gameItems.balanceOf(alice, 1);
        uint256 partB = gameItems.balanceOf(alice, 2);
        assertGt(partA + partB, 0);
    }
    function test_farmLootMultiple() public {
        vm.prank(alice);
        engine.farmLoot(5);
        assertEq(engine.totalLoots(), 5);
    }
    function test_farmLootZeroReverts() public {
        vm.prank(alice); vm.expectRevert("Loops: 1-10"); engine.farmLoot(0);
    }
    function test_farmLootOver10Reverts() public {
        vm.prank(alice); vm.expectRevert("Loops: 1-10"); engine.farmLoot(11);
    }
    function test_farmLootPureSolidity() public {
        vm.prank(alice);
        engine.farmLootPureSolidity(3);
        assertEq(engine.totalLoots(), 3);
    }
    function test_pause() public {
        vm.prank(deployer); engine.pause();
        vm.prank(alice); vm.expectRevert(); engine.farmLoot(1);
    }
    function test_unpause() public {
        vm.prank(deployer); engine.pause();
        vm.prank(deployer); engine.unpause();
        vm.prank(alice); engine.farmLoot(1);
    }
    function test_setDropChance() public {
        vm.prank(deployer); engine.setDropChance(5000);
        assertEq(engine.dropChanceBps(), 5000);
    }
    function test_setDropChanceRevertNonOwner() public {
        vm.prank(alice); vm.expectRevert(); engine.setDropChance(5000);
    }
    function test_setDropChanceRevertOver10000() public {
        vm.prank(deployer); vm.expectRevert("Max 10000 bps"); engine.setDropChance(10001);
    }

    // UUPS upgrade test
    function test_upgradeToV2() public {
        GameEngineV2 v2Impl = new GameEngineV2();
        vm.prank(deployer);
        engine.upgradeToAndCall(address(v2Impl), abi.encodeCall(GameEngineV2.initializeV2, (5)));
        GameEngineV2 engineV2 = GameEngineV2(address(engineProxy));
        assertEq(engineV2.version(), "2.0.0");
        assertEq(engineV2.maxLoopsPerTx(), 5);
    }
    function test_upgradeRevertNonOwner() public {
        GameEngineV2 v2Impl = new GameEngineV2();
        vm.prank(alice); vm.expectRevert(); engine.upgradeToAndCall(address(v2Impl), "");
    }
}
