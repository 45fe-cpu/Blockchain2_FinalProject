# AITU GameFi Subgraph Queries

## 1. Latest loot farming events
```graphql
query LatestLoots {
  lootFarms(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    itemId
    loops
    timestamp
    player { id lootCount }
  }
}
```

## 2. Latest sword crafts
```graphql
query LatestCrafts {
  crafts(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    feeCharged
    timestamp
    crafter { id craftCount }
  }
}
```

## 3. Player inventory balances
```graphql
query PlayerInventory($player: ID!) {
  player(id: $player) {
    id
    lootCount
    craftCount
    swapCount
    itemBalances {
      id
      balance
      item { itemId totalMinted }
    }
  }
}
```

## 4. Latest AMM swaps
```graphql
query LatestSwaps {
  swaps(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    tokenIn
    amountIn
    amountOut
    timestamp
    user { id swapCount }
  }
}
```

## 5. Governance proposals and votes
```graphql
query GovernanceOverview {
  proposals(first: 10, orderBy: createdAt, orderDirection: desc) {
    id
    description
    state
    forVotes
    againstVotes
    abstainVotes
    proposer { id }
  }
  voteCastEvents(first: 10, orderBy: timestamp, orderDirection: desc) {
    voter { id }
    support
    weight
    proposal { id description }
  }
}
```

## 6. Iron shop purchases
```graphql
query IronPurchases {
  ironPurchases(first: 10, orderBy: timestamp, orderDirection: desc) {
    buyer { id purchaseCount }
    ethSpent
    ironReceived
    timestamp
  }
}
```

## 7. Protocol parameter changes
```graphql
query ConfigChanges {
  protocolConfigChanges(first: 20, orderBy: timestamp, orderDirection: desc) {
    contractName
    parameter
    oldValue
    newValue
    newAddress
    timestamp
  }
}
```
