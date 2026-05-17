// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseSetup.t.sol";

contract AMMTest is BaseSetup {
    function _addLiquidity(uint256 a, uint256 b) internal {
        vm.startPrank(deployer);
        govToken.approve(address(amm), a);
        ironToken.approve(address(amm), b);
        amm.addLiquidity(a, b);
        vm.stopPrank();
    }

    function test_addLiquidity() public {
        _addLiquidity(1000e18, 1000e18);
        assertGt(amm.totalSupply(), 0);
        assertEq(amm.reserveA(), 1000e18);
        assertEq(amm.reserveB(), 1000e18);
    }

    function test_addLiquidityZeroReverts() public {
        vm.prank(deployer);
        vm.expectRevert("Amounts must be > 0");
        amm.addLiquidity(0, 100e18);
    }

    function test_removeLiquidity() public {
        _addLiquidity(1000e18, 1000e18);
        uint256 lp = amm.balanceOf(deployer);
        vm.startPrank(deployer);
        amm.removeLiquidity(lp);
        vm.stopPrank();
        assertEq(amm.reserveA(), 0);
    }

    function test_removeLiquidityZeroReverts() public {
        vm.prank(deployer);
        vm.expectRevert("LP must be > 0");
        amm.removeLiquidity(0);
    }

    function test_swap() public {
        _addLiquidity(1000e18, 1000e18);
        vm.startPrank(alice);
        govToken.approve(address(amm), 10e18);
        uint256 out = amm.swap(address(govToken), 10e18, 1);
        vm.stopPrank();
        assertGt(out, 0);
    }

    function test_swapSlippageReverts() public {
        _addLiquidity(1000e18, 1000e18);
        vm.startPrank(alice);
        govToken.approve(address(amm), 10e18);
        vm.expectRevert("Slippage exceeded");
        amm.swap(address(govToken), 10e18, 999e18);
        vm.stopPrank();
    }

    function test_swapInvalidToken() public {
        _addLiquidity(1000e18, 1000e18);
        vm.prank(alice);
        vm.expectRevert("Invalid token");
        amm.swap(address(0xdead), 10e18, 0);
    }

    function test_swapZeroAmount() public {
        _addLiquidity(1000e18, 1000e18);
        vm.prank(alice);
        vm.expectRevert("Amount must be > 0");
        amm.swap(address(govToken), 0, 0);
    }

    function test_getPrice() public {
        _addLiquidity(1000e18, 2000e18);
        assertEq(amm.getPrice(), 2e18);
    }

    function test_getAmountOut() public {
        _addLiquidity(1000e18, 1000e18);
        uint256 out = amm.getAmountOut(address(govToken), 10e18);
        assertGt(out, 0);
    }

    function test_swapBothDirections() public {
        _addLiquidity(1000e18, 1000e18);
        vm.startPrank(alice);
        ironToken.approve(address(amm), 10e18);
        uint256 out = amm.swap(address(ironToken), 10e18, 1);
        vm.stopPrank();
        assertGt(out, 0);
    }
}

contract AMMFactoryTest is BaseSetup {
    function test_createPool() public {
        vm.prank(deployer);
        address pool = ammFactory.createPool(address(govToken), address(ironToken));
        assertEq(ammFactory.allPoolsLength(), 1);
        assertEq(ammFactory.getPool(address(govToken), address(ironToken)), pool);
    }

    function test_createPoolDeterministic() public {
        bytes32 salt = keccak256("test-salt");
        address predicted = ammFactory.computePoolAddress(address(govToken), address(ironToken), salt);
        vm.prank(deployer);
        address pool = ammFactory.createPoolDeterministic(address(govToken), address(ironToken), salt);
        assertEq(pool, predicted);
    }

    function test_createPoolDuplicateReverts() public {
        vm.prank(deployer);
        ammFactory.createPool(address(govToken), address(ironToken));
        vm.prank(deployer);
        vm.expectRevert("Pool exists");
        ammFactory.createPool(address(govToken), address(ironToken));
    }

    function test_createPoolSameTokenReverts() public {
        vm.prank(deployer);
        vm.expectRevert("Identical tokens");
        ammFactory.createPool(address(govToken), address(govToken));
    }

    function test_createPoolNonOwnerReverts() public {
        vm.prank(alice);
        vm.expectRevert("Not owner");
        ammFactory.createPool(address(govToken), address(ironToken));
    }
}
