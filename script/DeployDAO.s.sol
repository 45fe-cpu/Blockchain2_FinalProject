// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/GovToken.sol";
import "../src/Timelock.sol";
import "../src/MyGovernor.sol";
import "../src/IronToken.sol";
import "../src/GameItems.sol";
import "../src/GameEngineV1.sol";
import "../src/IronVault.sol";
import "../src/AMM.sol";
import "../src/AMMFactory.sol";
import "../src/IronShop.sol";
import "../src/MockV3Aggregator.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDAO is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address dep = vm.addr(pk);
        console.log("Deployer:", dep);
        vm.startBroadcast(pk);

        // Phase 1: Governance
        GovToken gov = new GovToken(dep);
        gov.delegate(dep);
        (Timelock tl, MyGovernor gvnr) = _deployGov(gov, dep);

        // Phase 2: Game Economy
        IronToken iron = new IronToken(dep);
        iron.mint(dep, 1000000 * 1e18);
        (GameItems items, address proxy) = _deployGame(iron, dep);

        // Phase 3: DeFi
        _deployDeFi(gov, iron, dep);

        // Phase 4: Ownership handoff
        iron.transferOwnership(address(tl));
        GameEngineV1(proxy).transferOwnership(address(tl));
        tl.renounceRole(tl.DEFAULT_ADMIN_ROLE(), dep);

        vm.stopBroadcast();
        _logAddresses(gov, tl, gvnr, iron, items, proxy);
    }

    function _deployGov(GovToken gov, address dep) internal returns (Timelock, MyGovernor) {
        address[] memory p = new address[](1);
        address[] memory e = new address[](1);
        p[0] = address(0);
        e[0] = address(0);
        Timelock tl = new Timelock(10, p, e, dep);
        MyGovernor gvnr = new MyGovernor(IVotes(address(gov)), tl);
        tl.grantRole(tl.PROPOSER_ROLE(), address(gvnr));
        tl.grantRole(tl.CANCELLER_ROLE(), address(gvnr));
        console.log("Timelock:", address(tl));
        console.log("Governor:", address(gvnr));
        return (tl, gvnr);
    }

    function _deployGame(IronToken iron, address dep) internal returns (GameItems, address) {
        GameItems items = new GameItems(dep, address(iron), 10 * 1e18);
        GameEngineV1 impl = new GameEngineV1();
        bytes memory init = abi.encodeCall(GameEngineV1.initialize, (address(items), dep));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        items.transferOwnership(address(proxy));
        console.log("GameItems:", address(items));
        console.log("GameEngine:", address(proxy));
        return (items, address(proxy));
    }

    function _deployDeFi(GovToken gov, IronToken iron, address dep) internal {
        IronVault v = new IronVault(IERC20(address(iron)), dep);
        AMM a = new AMM(address(gov), address(iron));

        // Add initial liquidity to AMM so users can buy GOV
        gov.approve(address(a), 500_000 * 1e18);
        iron.approve(address(a), 500_000 * 1e18);
        a.addLiquidity(500_000 * 1e18, 500_000 * 1e18);

        AMMFactory af = new AMMFactory();
        MockV3Aggregator oracle = new MockV3Aggregator(8, 2000 * 1e8);
        IronShop shop = new IronShop(address(oracle), address(iron), 2000 * 1e8, 3600, dep);
        iron.mint(address(shop), 100_000 * 1e18);
        console.log("Vault:", address(v));
        console.log("AMM:", address(a));
        console.log("Factory:", address(af));
        console.log("Oracle:", address(oracle));
        console.log("Shop:", address(shop));
    }

    function _logAddresses(GovToken g, Timelock t, MyGovernor gv, IronToken i, GameItems gi, address px) internal pure {
        console.log("=== DEPLOYED ===");
        console.log("GovToken:", address(g));
        console.log("Timelock:", address(t));
        console.log("Governor:", address(gv));
        console.log("IronToken:", address(i));
        console.log("GameItems:", address(gi));
        console.log("GameEngine:", px);
    }
}
