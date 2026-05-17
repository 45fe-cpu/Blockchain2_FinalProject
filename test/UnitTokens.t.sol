// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseSetup.t.sol";

contract GovTokenTest is BaseSetup {
    function test_name() public view { assertEq(govToken.name(), "GovToken"); }
    function test_symbol() public view { assertEq(govToken.symbol(), "GOV"); }
    function test_initialSupply() public view { assertGt(govToken.totalSupply(), 0); }
    function test_deployerBalance() public view { assertGt(govToken.balanceOf(deployer), 0); }
    function test_mint() public { vm.prank(deployer); govToken.mint(alice, 100e18); assertGe(govToken.balanceOf(alice), 100e18); }
    function test_mintRevertNonOwner() public { vm.prank(alice); vm.expectRevert(); govToken.mint(alice, 100e18); }
    function test_delegate() public view { assertGt(govToken.getVotes(alice), 0); }
    function test_permit() public view { assertEq(govToken.nonces(alice), 0); }
    function test_transfer() public { vm.prank(alice); govToken.transfer(bob, 100e18); }
    function test_votingPower() public view { assertGt(govToken.getVotes(deployer), 0); }
}

contract IronTokenTest is BaseSetup {
    function test_name() public view { assertEq(ironToken.name(), "IronToken"); }
    function test_symbol() public view { assertEq(ironToken.symbol(), "IRON"); }
    function test_mint() public { vm.prank(deployer); ironToken.mint(alice, 50e18); }
    function test_mintRevertNonOwner() public { vm.prank(alice); vm.expectRevert(); ironToken.mint(alice, 50e18); }
    function test_burn() public { vm.prank(alice); ironToken.burn(10e18); }
    function test_burnExceedsBalance() public { vm.prank(alice); vm.expectRevert(); ironToken.burn(999_999e18); }
}

contract GameItemsTest is BaseSetup {
    function test_constants() public view {
        assertEq(gameItems.PART_A(), 1);
        assertEq(gameItems.PART_B(), 2);
        assertEq(gameItems.LEGENDARY_SWORD(), 3);
    }
    function test_craftingFee() public view { assertEq(gameItems.craftingFee(), 10e18); }
    function test_mintByEngine() public {
        vm.prank(address(engine));
        gameItems.mint(alice, 1, 5, "");
        assertEq(gameItems.balanceOf(alice, 1), 5);
    }
    function test_mintRevertNonOwner() public { vm.prank(alice); vm.expectRevert(); gameItems.mint(alice, 1, 1, ""); }
    function test_craftSword() public {
        vm.prank(address(engine)); gameItems.mint(alice, 1, 1, "");
        vm.prank(address(engine)); gameItems.mint(alice, 2, 1, "");
        vm.startPrank(alice);
        ironToken.approve(address(gameItems), 10e18);
        gameItems.craftSword();
        vm.stopPrank();
        assertEq(gameItems.balanceOf(alice, 3), 1);
        assertEq(gameItems.balanceOf(alice, 1), 0);
        assertEq(gameItems.balanceOf(alice, 2), 0);
    }
    function test_craftSwordNoPartA() public {
        vm.prank(address(engine)); gameItems.mint(alice, 2, 1, "");
        vm.prank(alice); vm.expectRevert("Need Part A"); gameItems.craftSword();
    }
    function test_craftSwordNoPartB() public {
        vm.prank(address(engine)); gameItems.mint(alice, 1, 1, "");
        vm.prank(alice); vm.expectRevert("Need Part B"); gameItems.craftSword();
    }
}
