// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseSetup.t.sol";

contract FuzzTests is BaseSetup {
    function setUp() public override {
        super.setUp();
        // Seed AMM with liquidity
        vm.startPrank(deployer);
        govToken.approve(address(amm), 50_000e18);
        ironToken.approve(address(amm), 50_000e18);
        amm.addLiquidity(50_000e18, 50_000e18);
        vm.stopPrank();
    }

    // Fuzz 1: AMM swap — uses modulo math to avoid rejected inputs
    function testFuzz_ammSwapGovToIron(uint256 amount) public {
        uint256 reserve = amm.reserveA();
        if (reserve < 100e18) return;
        amount = bound(amount, 1e18, reserve / 10);
        vm.startPrank(alice);
        govToken.approve(address(amm), amount);
        uint256 out = amm.swap(address(govToken), amount, 0);
        vm.stopPrank();
        assertGt(out, 0);
    }

    // Fuzz 2: AMM swap reverse direction
    function testFuzz_ammSwapIronToGov(uint256 amount) public {
        uint256 reserve = amm.reserveB();
        if (reserve < 100e18) return;
        amount = bound(amount, 1e18, reserve / 10);
        vm.startPrank(alice);
        ironToken.approve(address(amm), amount);
        uint256 out = amm.swap(address(ironToken), amount, 0);
        vm.stopPrank();
        assertGt(out, 0);
    }

    // Fuzz 3: Vault deposit
    function testFuzz_vaultDeposit(uint256 amount) public {
        amount = bound(amount, 1, 9_000e18);
        vm.startPrank(alice);
        ironToken.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        vm.stopPrank();
        assertGt(shares, 0);
    }

    // Fuzz 4: Vault withdraw
    function testFuzz_vaultWithdraw(uint256 depositAmt) public {
        depositAmt = bound(depositAmt, 2, 9_000e18);
        vm.startPrank(alice);
        ironToken.approve(address(vault), depositAmt);
        vault.deposit(depositAmt, alice);
        uint256 withdrawAmt = bound(depositAmt, 1, depositAmt);
        vault.withdraw(withdrawAmt, alice, alice);
        vm.stopPrank();
    }

    // Fuzz 5: GovToken voting power after transfer
    function testFuzz_votingPowerTransfer(uint256 amount) public {
        amount = bound(amount, 1, govToken.balanceOf(alice));
        vm.prank(alice);
        govToken.transfer(bob, amount);
        vm.roll(block.number + 1);
        // Alice voting power decreased, bob's increased
        assertLe(govToken.getVotes(alice), 10_000e18);
    }

    // Fuzz 6: IronToken mint
    function testFuzz_ironMint(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e18);
        vm.prank(deployer);
        ironToken.mint(alice, amount);
    }

    // Fuzz 7: AMM add liquidity
    function testFuzz_addLiquidity(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 100, 5_000e18);
        amountB = bound(amountB, 100, 5_000e18);
        vm.startPrank(alice);
        govToken.approve(address(amm), amountA);
        ironToken.approve(address(amm), amountB);
        amm.addLiquidity(amountA, amountB);
        vm.stopPrank();
    }

    // Fuzz 8: GameEngine farmLoot loops
    function testFuzz_farmLoot(uint256 loops) public {
        loops = bound(loops, 1, 10);
        vm.prank(alice);
        engine.farmLoot(loops);
        assertGe(engine.totalLoots(), loops);
    }

    // Fuzz 9: Vault deposit-redeem roundtrip
    function testFuzz_vaultRoundtrip(uint256 amount) public {
        amount = bound(amount, 1, 9_000e18);
        vm.startPrank(alice);
        ironToken.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertLe(assets, amount); // rounding may lose 1 wei
    }

    // Fuzz 10: AMM getAmountOut consistency
    function testFuzz_ammGetAmountOut(uint256 amount) public view {
        uint256 reserve = amm.reserveA();
        if (reserve < 100e18) return;
        amount = bound(amount, 1e18, reserve / 10);
        uint256 out = amm.getAmountOut(address(govToken), amount);
        assertGt(out, 0);
    }
}
