import { BigInt, Bytes, Address } from "@graphprotocol/graph-ts";
import { ItemsMinted, SwordCrafted } from "../generated/GameItems/GameItems";
import { LootFarmed, DropChanceUpdated, MaxLoopsUpdated } from "../generated/GameEngine/GameEngine";
import { LiquidityAdded, LiquidityRemoved, Swap as SwapEvent } from "../generated/AMM/AMM";
import { PoolCreated } from "../generated/AMMFactory/AMMFactory";
import { IronPurchased, PriceFeedUpdated, IronPriceUpdated } from "../generated/IronShop/IronShop";
import { YieldAdded } from "../generated/IronVault/IronVault";
import { ProposalCreated, VoteCast, ProposalExecuted } from "../generated/MyGovernor/MyGovernor";
import {
  Player,
  Item,
  ItemBalance,
  LootFarm,
  Craft,
  Swap,
  LiquidityEvent,
  PoolCreation,
  IronPurchase,
  VaultYield,
  Proposal,
  VoteCastEvent,
  ProtocolConfigChange
} from "../generated/schema";

function eventId(hash: Bytes, logIndex: BigInt): string {
  return hash.toHexString() + "-" + logIndex.toString();
}

function getOrCreatePlayer(address: Address, timestamp: BigInt): Player {
  let id = address.toHexString();
  let player = Player.load(id);
  if (player == null) {
    player = new Player(id);
    player.address = address;
    player.lootCount = BigInt.zero();
    player.craftCount = BigInt.zero();
    player.purchaseCount = BigInt.zero();
    player.swapCount = BigInt.zero();
    player.voteCount = BigInt.zero();
    player.createdAt = timestamp;
  }
  player.updatedAt = timestamp;
  player.save();
  return player;
}

function getOrCreateItem(itemId: BigInt, timestamp: BigInt): Item {
  let id = itemId.toString();
  let item = Item.load(id);
  if (item == null) {
    item = new Item(id);
    item.itemId = itemId;
    item.totalMinted = BigInt.zero();
    item.holderCount = BigInt.zero();
  }
  item.updatedAt = timestamp;
  item.save();
  return item;
}

function getOrCreateItemBalance(player: Player, item: Item, timestamp: BigInt): ItemBalance {
  let id = player.id + "-" + item.id;
  let balance = ItemBalance.load(id);
  if (balance == null) {
    balance = new ItemBalance(id);
    balance.player = player.id;
    balance.item = item.id;
    balance.balance = BigInt.zero();
    item.holderCount = item.holderCount.plus(BigInt.fromI32(1));
    item.updatedAt = timestamp;
    item.save();
  }
  balance.updatedAt = timestamp;
  balance.save();
  return balance;
}

function saveConfigChange(
  id: string,
  contractName: string,
  parameter: string,
  oldValue: BigInt | null,
  newValue: BigInt | null,
  newAddress: Bytes | null,
  blockNumber: BigInt,
  timestamp: BigInt,
  txHash: Bytes
): void {
  let change = new ProtocolConfigChange(id);
  change.contractName = contractName;
  change.parameter = parameter;
  change.oldValue = oldValue;
  change.newValue = newValue;
  change.newAddress = newAddress;
  change.blockNumber = blockNumber;
  change.timestamp = timestamp;
  change.txHash = txHash;
  change.save();
}

export function handleItemsMinted(event: ItemsMinted): void {
  let player = getOrCreatePlayer(event.params.to, event.block.timestamp);
  let item = getOrCreateItem(event.params.id, event.block.timestamp);
  let balance = getOrCreateItemBalance(player, item, event.block.timestamp);

  balance.balance = balance.balance.plus(event.params.amount);
  balance.updatedAt = event.block.timestamp;
  balance.save();

  item.totalMinted = item.totalMinted.plus(event.params.amount);
  item.updatedAt = event.block.timestamp;
  item.save();
}

export function handleSwordCrafted(event: SwordCrafted): void {
  let player = getOrCreatePlayer(event.params.crafter, event.block.timestamp);
  player.craftCount = player.craftCount.plus(BigInt.fromI32(1));
  player.updatedAt = event.block.timestamp;
  player.save();

  let craft = new Craft(eventId(event.transaction.hash, event.logIndex));
  craft.crafter = player.id;
  craft.feeCharged = event.params.feeCharged;
  craft.blockNumber = event.block.number;
  craft.timestamp = event.block.timestamp;
  craft.txHash = event.transaction.hash;
  craft.save();
}

export function handleLootFarmed(event: LootFarmed): void {
  let player = getOrCreatePlayer(event.params.player, event.block.timestamp);
  player.lootCount = player.lootCount.plus(BigInt.fromI32(1));
  player.updatedAt = event.block.timestamp;
  player.save();

  let loot = new LootFarm(eventId(event.transaction.hash, event.logIndex));
  loot.player = player.id;
  loot.itemId = event.params.itemId;
  loot.loops = event.params.loops;
  loot.blockNumber = event.block.number;
  loot.timestamp = event.block.timestamp;
  loot.txHash = event.transaction.hash;
  loot.save();
}

export function handleDropChanceUpdated(event: DropChanceUpdated): void {
  saveConfigChange(
    eventId(event.transaction.hash, event.logIndex),
    "GameEngine",
    "dropChanceBps",
    event.params.oldChance,
    event.params.newChance,
    null,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleMaxLoopsUpdated(event: MaxLoopsUpdated): void {
  saveConfigChange(
    eventId(event.transaction.hash, event.logIndex),
    "GameEngineV2",
    "maxLoopsPerTx",
    event.params.oldMax,
    event.params.newMax,
    null,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let provider = getOrCreatePlayer(event.params.provider, event.block.timestamp);
  let record = new LiquidityEvent(eventId(event.transaction.hash, event.logIndex));
  record.provider = provider.id;
  record.action = "ADD";
  record.amountA = event.params.amountA;
  record.amountB = event.params.amountB;
  record.lpAmount = event.params.lpMinted;
  record.blockNumber = event.block.number;
  record.timestamp = event.block.timestamp;
  record.txHash = event.transaction.hash;
  record.save();
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let provider = getOrCreatePlayer(event.params.provider, event.block.timestamp);
  let record = new LiquidityEvent(eventId(event.transaction.hash, event.logIndex));
  record.provider = provider.id;
  record.action = "REMOVE";
  record.amountA = event.params.amountA;
  record.amountB = event.params.amountB;
  record.lpAmount = event.params.lpBurned;
  record.blockNumber = event.block.number;
  record.timestamp = event.block.timestamp;
  record.txHash = event.transaction.hash;
  record.save();
}

export function handleSwap(event: SwapEvent): void {
  let user = getOrCreatePlayer(event.params.user, event.block.timestamp);
  user.swapCount = user.swapCount.plus(BigInt.fromI32(1));
  user.updatedAt = event.block.timestamp;
  user.save();

  let swap = new Swap(eventId(event.transaction.hash, event.logIndex));
  swap.user = user.id;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.blockNumber = event.block.number;
  swap.timestamp = event.block.timestamp;
  swap.txHash = event.transaction.hash;
  swap.save();
}

export function handlePoolCreated(event: PoolCreated): void {
  let pool = new PoolCreation(eventId(event.transaction.hash, event.logIndex));
  pool.tokenA = event.params.tokenA;
  pool.tokenB = event.params.tokenB;
  pool.pool = event.params.pool;
  pool.poolIndex = event.params.poolIndex;
  pool.blockNumber = event.block.number;
  pool.timestamp = event.block.timestamp;
  pool.txHash = event.transaction.hash;
  pool.save();
}

export function handleIronPurchased(event: IronPurchased): void {
  let buyer = getOrCreatePlayer(event.params.buyer, event.block.timestamp);
  buyer.purchaseCount = buyer.purchaseCount.plus(BigInt.fromI32(1));
  buyer.updatedAt = event.block.timestamp;
  buyer.save();

  let purchase = new IronPurchase(eventId(event.transaction.hash, event.logIndex));
  purchase.buyer = buyer.id;
  purchase.ethSpent = event.params.ethSpent;
  purchase.ironReceived = event.params.ironReceived;
  purchase.blockNumber = event.block.number;
  purchase.timestamp = event.block.timestamp;
  purchase.txHash = event.transaction.hash;
  purchase.save();
}

export function handlePriceFeedUpdated(event: PriceFeedUpdated): void {
  saveConfigChange(
    eventId(event.transaction.hash, event.logIndex),
    "IronShop",
    "priceFeed",
    null,
    null,
    event.params.newFeed,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleIronPriceUpdated(event: IronPriceUpdated): void {
  saveConfigChange(
    eventId(event.transaction.hash, event.logIndex),
    "IronShop",
    "ironPriceUsd",
    null,
    event.params.newPrice,
    null,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash
  );
}

export function handleYieldAdded(event: YieldAdded): void {
  let record = new VaultYield(eventId(event.transaction.hash, event.logIndex));
  record.amount = event.params.amount;
  record.blockNumber = event.block.number;
  record.timestamp = event.block.timestamp;
  record.txHash = event.transaction.hash;
  record.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let proposer = getOrCreatePlayer(event.params.proposer, event.block.timestamp);
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposalId = event.params.proposalId;
  proposal.proposer = proposer.id;
  proposal.description = event.params.description;
  proposal.voteStart = event.params.voteStart;
  proposal.voteEnd = event.params.voteEnd;
  proposal.state = "Created";
  proposal.forVotes = BigInt.zero();
  proposal.againstVotes = BigInt.zero();
  proposal.abstainVotes = BigInt.zero();
  proposal.createdAt = event.block.timestamp;
  proposal.txHash = event.transaction.hash;
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let voter = getOrCreatePlayer(event.params.voter, event.block.timestamp);
  voter.voteCount = voter.voteCount.plus(BigInt.fromI32(1));
  voter.updatedAt = event.block.timestamp;
  voter.save();

  let proposalId = event.params.proposalId.toString();
  let proposal = Proposal.load(proposalId);
  if (proposal == null) {
    proposal = new Proposal(proposalId);
    proposal.proposalId = event.params.proposalId;
    proposal.proposer = voter.id;
    proposal.description = "Unknown proposal indexed from vote";
    proposal.voteStart = BigInt.zero();
    proposal.voteEnd = BigInt.zero();
    proposal.state = "Unknown";
    proposal.forVotes = BigInt.zero();
    proposal.againstVotes = BigInt.zero();
    proposal.abstainVotes = BigInt.zero();
    proposal.createdAt = event.block.timestamp;
    proposal.txHash = event.transaction.hash;
  }

  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }
  proposal.save();

  let vote = new VoteCastEvent(eventId(event.transaction.hash, event.logIndex));
  vote.proposal = proposal.id;
  vote.voter = voter.id;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.blockNumber = event.block.number;
  vote.timestamp = event.block.timestamp;
  vote.txHash = event.transaction.hash;
  vote.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;
  proposal.state = "Executed";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}
