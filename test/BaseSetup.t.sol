// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GovToken.sol";
import "../src/Timelock.sol";
import "../src/MyGovernor.sol";
import "../src/IronToken.sol";
import "../src/GameItems.sol";
import "../src/GameEngineV1.sol";
import "../src/GameEngineV2.sol";
import "../src/IronVault.sol";
import "../src/AMM.sol";
import "../src/AMMFactory.sol";
import "../src/IronShop.sol";
import "../src/MockV3Aggregator.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BaseSetup is Test {
    GovToken public govToken;
    Timelock public timelock;
    MyGovernor public governor;
    IronToken public ironToken;
    GameItems public gameItems;
    GameEngineV1 public engineImpl;
    GameEngineV1 public engine; // proxy cast
    ERC1967Proxy public engineProxy;
    IronVault public vault;
    AMM public amm;
    AMMFactory public ammFactory;
    MockV3Aggregator public mockOracle;
    IronShop public ironShop;

    address public deployer = address(1);
    address public alice = address(2);
    address public bob = address(3);

    function setUp() public virtual {
        vm.startPrank(deployer);

        govToken = new GovToken(deployer);
        govToken.delegate(deployer);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0);
        executors[0] = address(0);
        timelock = new Timelock(10, proposers, executors, deployer);

        governor = new MyGovernor(IVotes(address(govToken)), timelock);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        ironToken = new IronToken(deployer);
        ironToken.mint(deployer, 100_000 * 1e18);

        gameItems = new GameItems(deployer, address(ironToken), 10 * 1e18);

        engineImpl = new GameEngineV1();
        bytes memory initData = abi.encodeCall(GameEngineV1.initialize, (address(gameItems), deployer));
        engineProxy = new ERC1967Proxy(address(engineImpl), initData);
        engine = GameEngineV1(address(engineProxy));

        gameItems.transferOwnership(address(engine));

        vault = new IronVault(IERC20(address(ironToken)), deployer);
        amm = new AMM(address(govToken), address(ironToken));
        ammFactory = new AMMFactory();

        mockOracle = new MockV3Aggregator(8, 2000 * 1e8);
        ironShop = new IronShop(address(mockOracle), address(ironToken), 1e8, 3600, deployer);

        // Give alice and bob tokens
        govToken.transfer(alice, 10_000 * 1e18);
        govToken.transfer(bob, 10_000 * 1e18);
        ironToken.mint(alice, 10_000 * 1e18);
        ironToken.mint(bob, 10_000 * 1e18);

        vm.stopPrank();

        vm.prank(alice);
        govToken.delegate(alice);
        vm.prank(bob);
        govToken.delegate(bob);

        vm.roll(block.number + 1);
    }
}
