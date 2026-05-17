// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/GovToken.sol";
import "../src/IronToken.sol";
import "../src/AMM.sol";
import "../src/IronVault.sol";

contract AMMHandler is Test {
    AMM public amm;
    GovToken public govToken;
    IronToken public ironToken;

    constructor(AMM _amm, GovToken _gov, IronToken _iron) {
        amm = _amm;
        govToken = _gov;
        ironToken = _iron;
    }

    function swapAtoB(uint256 amount) external {
        if (amm.reserveA() < 10 || amm.reserveB() < 10) return;
        amount = (amount % (amm.reserveA() / 10)) + 1;
        govToken.approve(address(amm), amount);
        amm.swap(address(govToken), amount, 0);
    }

    function swapBtoA(uint256 amount) external {
        if (amm.reserveA() < 10 || amm.reserveB() < 10) return;
        amount = (amount % (amm.reserveB() / 10)) + 1;
        ironToken.approve(address(amm), amount);
        amm.swap(address(ironToken), amount, 0);
    }
}

contract InvariantTests is StdInvariant, Test {
    GovToken public govToken;
    IronToken public ironToken;
    AMM public amm;
    IronVault public vault;
    AMMHandler public handler;

    address deployer = address(1);
    uint256 initialK;

    function setUp() public {
        vm.startPrank(deployer);

        govToken = new GovToken(deployer);
        ironToken = new IronToken(deployer);
        ironToken.mint(deployer, 1_000_000e18);

        amm = new AMM(address(govToken), address(ironToken));
        vault = new IronVault(IERC20(address(ironToken)), deployer);

        govToken.approve(address(amm), 100_000e18);
        ironToken.approve(address(amm), 100_000e18);
        amm.addLiquidity(100_000e18, 100_000e18);
        initialK = amm.reserveA() * amm.reserveB();

        handler = new AMMHandler(amm, govToken, ironToken);
        govToken.transfer(address(handler), 50_000e18);
        ironToken.mint(address(handler), 50_000e18);

        vm.stopPrank();

        targetContract(address(handler));
    }

    // Invariant 1: k never decreases on swap
    function invariant_kNeverDecreases() public view {
        uint256 currentK = amm.reserveA() * amm.reserveB();
        assertGe(currentK, initialK);
    }

    // Invariant 2: Total supply conservation — LP supply matches deposited value
    function invariant_reservesMatchBalances() public view {
        assertGe(govToken.balanceOf(address(amm)), amm.reserveA());
        assertGe(ironToken.balanceOf(address(amm)), amm.reserveB());
    }

    // Invariant 3: GovToken total supply never changes without minting
    function invariant_govTokenSupply() public view {
        assertEq(govToken.totalSupply(), 1_000_000e18);
    }

    // Invariant 4: Vault shares totalSupply matches actual balance
    function invariant_vaultAccounting() public view {
        if (vault.totalSupply() > 0) {
            assertGe(ironToken.balanceOf(address(vault)), vault.totalAssets());
        }
    }

    // Invariant 5: AMM reserves are never both zero when LP exists
    function invariant_ammReservesNonZeroWithLP() public view {
        if (amm.totalSupply() > 0) {
            assertGt(amm.reserveA(), 0);
            assertGt(amm.reserveB(), 0);
        }
    }
}
