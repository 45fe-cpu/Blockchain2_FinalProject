// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseSetup.t.sol";

contract VaultTest is BaseSetup {
    function test_deposit() public {
        vm.startPrank(alice);
        ironToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
    }
    function test_withdraw() public {
        vm.startPrank(alice);
        ironToken.approve(address(vault), 100e18);
        vault.deposit(100e18, alice);
        vault.withdraw(50e18, alice, alice);
        vm.stopPrank();
    }
    function test_redeem() public {
        vm.startPrank(alice);
        ironToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertEq(vault.balanceOf(alice), 0);
    }
    function test_addYield() public {
        vm.startPrank(alice);
        ironToken.approve(address(vault), 100e18);
        vault.deposit(100e18, alice);
        vm.stopPrank();

        vm.startPrank(deployer);
        ironToken.approve(address(vault), 50e18);
        vault.addYield(50e18);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 150e18);
    }
    function test_addYieldNonOwnerReverts() public {
        vm.prank(alice); vm.expectRevert(); vault.addYield(10e18);
    }
    function test_previewDeposit() public view {
        uint256 shares = vault.previewDeposit(100e18);
        assertGt(shares, 0);
    }
    function test_previewRedeem() public {
        vm.startPrank(alice);
        ironToken.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18, alice);
        vm.stopPrank();
        uint256 assets = vault.previewRedeem(shares);
        assertEq(assets, 100e18);
    }
    function test_maxDeposit() public view { assertGt(vault.maxDeposit(alice), 0); }
    function test_asset() public view { assertEq(vault.asset(), address(ironToken)); }
}

contract IronShopTest is BaseSetup {
    function test_buyIron() public {
        vm.deal(alice, 1 ether);
        // For test, give IronShop liquidity to sell
        vm.prank(deployer);
        ironToken.mint(address(ironShop), 100000e18);

        vm.prank(alice);
        ironShop.buyIron{value: 1 ether}();
        assertGt(ironToken.balanceOf(alice), 10_000e18); // original + purchase
    }
    function test_buyIronZeroReverts() public {
        vm.prank(alice); vm.expectRevert("Must send ETH");
        ironShop.buyIron{value: 0}();
    }
    function test_staleOracleReverts() public {
        vm.warp(block.timestamp + 7200); // 2 hours > 1 hour threshold
        vm.deal(alice, 1 ether);
        vm.prank(deployer); ironToken.mint(address(ironShop), 100000e18);
        vm.prank(alice); vm.expectRevert("Stale oracle price");
        ironShop.buyIron{value: 1 ether}();
    }
    function test_withdrawETH() public {
        vm.deal(address(ironShop), 1 ether);
        vm.prank(deployer);
        ironShop.withdrawETH(payable(deployer));
        assertEq(address(ironShop).balance, 0);
    }
    function test_withdrawETHNonOwnerReverts() public {
        vm.deal(address(ironShop), 1 ether);
        vm.prank(alice); vm.expectRevert();
        ironShop.withdrawETH(payable(alice));
    }
    function test_setPriceFeed() public {
        MockV3Aggregator newFeed = new MockV3Aggregator(8, 3000e8);
        vm.prank(deployer); ironShop.setPriceFeed(address(newFeed));
    }
    function test_setIronPrice() public {
        vm.prank(deployer); ironShop.setIronPrice(2e8);
        assertEq(ironShop.ironPriceUsd(), 2e8);
    }
}

contract GovernanceTest is BaseSetup {
    function test_governorName() public view { assertEq(governor.name(), "MyGovernor"); }
    function test_votingDelay() public view { assertEq(governor.votingDelay(), 1); }
    function test_votingPeriod() public view { assertEq(governor.votingPeriod(), 5); }
    function test_proposalThreshold() public view { assertEq(governor.proposalThreshold(), 1e18); }
    function test_quorumFraction() public view { assertEq(governor.quorumNumerator(), 4); }

    function test_fullGovernanceLifecycle() public {
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(engine);
        calldatas[0] = abi.encodeCall(GameEngineV1.setDropChance, (5000));

        // Need to transfer engine ownership to timelock for governance
        vm.prank(deployer);
        engine.transferOwnership(address(timelock));

        vm.prank(deployer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set drop to 50%");

        // Advance past voting delay (1 block)
        vm.roll(block.number + 2);

        // Vote
        vm.prank(deployer);
        governor.castVote(proposalId, 1); // For

        // Advance past voting period (5 blocks)
        vm.roll(block.number + 6);

        // Queue
        governor.queue(targets, values, calldatas, keccak256("Set drop to 50%"));

        // Advance past timelock delay (10 seconds)
        vm.warp(block.timestamp + 11);

        // Execute
        governor.execute(targets, values, calldatas, keccak256("Set drop to 50%"));

        assertEq(engine.dropChanceBps(), 5000);
    }
}

contract TimelockTest is BaseSetup {
    function test_minDelay() public view { assertEq(timelock.getMinDelay(), 10); }
    function test_governorIsProposer() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
    }
}
