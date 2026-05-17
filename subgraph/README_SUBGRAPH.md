# AITU GameFi Subgraph

This subgraph indexes the latest Blockchain2_FinalProject project, not the old A3 project.

Indexed contracts:
- GameItems: ItemsMinted, SwordCrafted
- GameEngine proxy: LootFarmed, DropChanceUpdated, MaxLoopsUpdated
- AMM: LiquidityAdded, LiquidityRemoved, Swap
- AMMFactory: PoolCreated
- IronShop: IronPurchased, PriceFeedUpdated, IronPriceUpdated
- IronVault: YieldAdded
- MyGovernor: ProposalCreated, VoteCast, ProposalExecuted

Before building, replace all placeholders in subgraph.yaml:
- GAME_ITEMS_ADDRESS
- GAME_ENGINE_PROXY_ADDRESS
- AMM_ADDRESS
- AMM_FACTORY_ADDRESS
- IRON_SHOP_ADDRESS
- IRON_VAULT_ADDRESS
- GOVERNOR_ADDRESS
- START_BLOCK

Commands:
```bash
cd subgraph
npm install
npm run codegen
npm run build
```

Deploy to The Graph Studio:
```bash
graph auth --studio YOUR_DEPLOY_KEY
npm run deploy:studio
```
