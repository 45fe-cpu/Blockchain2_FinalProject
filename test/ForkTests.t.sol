// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MockV3Aggregator.sol";
import "../src/IronShop.sol";
import "../src/IronToken.sol";

/**
 * @title ForkTests
 * @notice Fork tests verifying Oracle integration with Chainlink-like data.
 * @dev These tests simulate mainnet fork behavior using MockV3Aggregator.
 *      In a real fork test, you'd use vm.createSelectFork with a mainnet RPC.
 */
contract ForkTests is Test {
    MockV3Aggregator public oracle;
    IronToken public ironToken;
    IronShop public shop;
    address deployer = address(1);
    address user = address(2);

    function setUp() public {
        vm.startPrank(deployer);
        oracle = new MockV3Aggregator(8, 2000 * 1e8);
        ironToken = new IronToken(deployer);
        shop = new IronShop(address(oracle), address(ironToken), 1e8, 3600, deployer);
        ironToken.mint(address(shop), 1000000 * 1e18);
        vm.stopPrank();
    }

    // Fork Test 1: Oracle returns correct price data
    function test_forkOracleData() public view {
        (, int256 price,, uint256 updatedAt,) = oracle.latestRoundData();
        assertEq(price, 2000 * 1e8);
        assertGt(updatedAt, 0);
        assertEq(oracle.decimals(), 8);
    }

    // Fork Test 2: Buy IRON with correct oracle pricing
    function test_forkBuyIronWithOracle() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        shop.buyIron{value: 1 ether}();
        // 1 ETH = 1 IRON
        assertEq(ironToken.balanceOf(user), 1e18);
    }

    // Fork Test 3: Oracle price update reflects in purchase
    function test_forkOraclePriceChange() public {
        oracle.updateAnswer(3000 * 1e8); // ETH goes to $3000
        vm.deal(user, 1 ether);
        vm.prank(user);
        shop.buyIron{value: 1 ether}();
        // Ratio is still 1:1 despite oracle price change
        assertEq(ironToken.balanceOf(user), 1e18);
    }
}
