// Configuration: Replace these with your actual deployed addresses
const CONTRACT_ADDRESSES = {
  GovToken: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  Timelock: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  Governor: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
  IronToken: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
  GameItems: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
  GameEngine: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
  IronVault: "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
  AMM: "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82",
  IronShop: "0x3aa5ebb10dc797cac828524e59a333d0a371443c",
  Oracle: "0x68b1d87f95878fe05b998f19b66f4baba5de1aed",
};

// Human-readable ABIs for required interactions
const ABIs = {
  ERC20: [
    "function balanceOf(address owner) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function getVotes(address account) view returns (uint256)",
    "function delegate(address delegatee)",
  ],
  GameEngine: ["function farmLoot(uint256 loops)"],
  GameItems: [
    "function balanceOf(address account, uint256 id) view returns (uint256)",
    "function craftSword()",
  ],
  IronVault: [
    "function deposit(uint256 assets, address receiver) returns (uint256)",
    "function withdraw(uint256 assets, address receiver, address owner) returns (uint256)",
    "function maxDeposit(address) view returns (uint256)",
    "function totalAssets() view returns (uint256)",
    "function balanceOf(address owner) view returns (uint256)",
  ],
  AMM: [
    "function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) returns (uint256)",
  ],
  IronShop: ["function buyIron() payable"],
  Oracle: [
    "function latestRoundData() view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
  ],
  Governor: [
    "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
    "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
    "function queue(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) returns (uint256)",
    "function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) payable returns (uint256)",
    "function state(uint256 proposalId) view returns (uint8)",
    "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
    "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description)",
  ],
};

// State
let provider;
let signer;
let userAddress;
let contracts = {};

// Initialize App
document.addEventListener("DOMContentLoaded", () => {
  initTabs();
  initWalletButton();
});

// Tab Navigation Logic
function initTabs() {
  const navItems = document.querySelectorAll(".nav-item");
  const tabContents = document.querySelectorAll(".tab-content");

  navItems.forEach((item) => {
    item.addEventListener("click", () => {
      // Remove active class from all
      navItems.forEach((n) => n.classList.remove("active"));
      tabContents.forEach((t) => t.classList.remove("active"));

      // Add active class to clicked tab
      item.classList.add("active");
      const tabId = item.getAttribute("data-tab");
      document.getElementById(tabId).classList.add("active");
    });
  });
}

// Wallet Connection
function initWalletButton() {
  const btn = document.getElementById("connectWalletBtn");
  btn.addEventListener("click", async () => {
    if (typeof window.ethereum !== "undefined") {
      try {
        await window.ethereum.request({ method: "eth_requestAccounts" });
        provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        userAddress = await signer.getAddress();

        // Update UI
        btn.textContent =
          userAddress.substring(0, 6) + "..." + userAddress.substring(38);
        document.getElementById("networkStatus").classList.add("connected");

        // Init contracts and load data
        initContracts();
        loadUserData();

        // Listen for account changes
        window.ethereum.on("accountsChanged", (accounts) => {
          if (
            accounts.length > 0 &&
            accounts[0].toLowerCase() !== userAddress.toLowerCase()
          ) {
            window.location.reload();
          } else if (accounts.length === 0) {
            window.location.reload();
          }
        });
      } catch (error) {
        console.error("Connection error:", error);
        alert("Failed to connect: " + (error.message || error));
      }
    } else {
      alert("Please install MetaMask!");
    }
  });
}

// Initialize Contract Instances
function initContracts() {
  // Only init if addresses are provided
  if (CONTRACT_ADDRESSES.IronToken.startsWith("0x...")) {
    console.warn(
      "Contract addresses not set. Please update CONTRACT_ADDRESSES."
    );
    return;
  }

  contracts.ironToken = new ethers.Contract(
    CONTRACT_ADDRESSES.IronToken,
    ABIs.ERC20,
    signer
  );
  contracts.govToken = new ethers.Contract(
    CONTRACT_ADDRESSES.GovToken,
    ABIs.ERC20,
    signer
  );
  contracts.gameEngine = new ethers.Contract(
    CONTRACT_ADDRESSES.GameEngine,
    ABIs.GameEngine,
    signer
  );
  contracts.gameItems = new ethers.Contract(
    CONTRACT_ADDRESSES.GameItems,
    ABIs.GameItems,
    signer
  );
  contracts.vault = new ethers.Contract(
    CONTRACT_ADDRESSES.IronVault,
    ABIs.IronVault,
    signer
  );
  contracts.amm = new ethers.Contract(CONTRACT_ADDRESSES.AMM, ABIs.AMM, signer);
  contracts.shop = new ethers.Contract(
    CONTRACT_ADDRESSES.IronShop,
    ABIs.IronShop,
    signer
  );
  contracts.oracle = new ethers.Contract(
    CONTRACT_ADDRESSES.Oracle,
    ABIs.Oracle,
    provider
  );
  contracts.governor = new ethers.Contract(
    CONTRACT_ADDRESSES.Governor,
    ABIs.Governor,
    signer
  );

  bindContractActions();
}

// Load User Data
async function loadUserData() {
  if (!contracts.ironToken) return;

  try {
    // Balances
    const ironBal = await contracts.ironToken.balanceOf(userAddress);
    const govBal = await contracts.govToken.balanceOf(userAddress);
    const ironBalFormatted = ethers.utils.formatEther(ironBal);
    document.getElementById("ironBalance").innerText = ironBalFormatted;
    document.getElementById("govBalance").innerText =
      ethers.utils.formatEther(govBal);

    // Header balance
    document.getElementById("headerIronBalance").innerText = `${parseFloat(
      ironBalFormatted
    ).toFixed(2)} IRON`;
    document.getElementById("headerIronBalance").style.display = "block";

    // Inventory
    const partA = await contracts.gameItems.balanceOf(userAddress, 1);
    const partB = await contracts.gameItems.balanceOf(userAddress, 2);
    const sword = await contracts.gameItems.balanceOf(userAddress, 3);

    renderInventory(partA.toNumber(), partB.toNumber(), sword.toNumber());

    // Vault
    const vaultShares = await contracts.vault.balanceOf(userAddress);
    const totalAssets = await contracts.vault.totalAssets();
    document.getElementById("stakedIron").innerText =
      ethers.utils.formatEther(vaultShares);
    document.getElementById("vaultTotalAssets").innerText =
      ethers.utils.formatEther(totalAssets);

    // Governance
    const votes = await contracts.govToken.getVotes(userAddress);
    document.getElementById("votingPower").innerText =
      ethers.utils.formatEther(votes);

    await loadProposals();

    // UI States (Craft button)
    if (partA > 0 && partB > 0) {
      document.getElementById("craftBtn").disabled = false;
    }
  } catch (e) {
    console.error("Error loading data:", e);
  }
}

function renderInventory(partA, partB, sword) {
  const container = document.getElementById("inventoryContainer");
  container.innerHTML = ""; // Clear existing

  let totalItems = partA + partB + sword;
  if (totalItems === 0) {
    container.innerHTML = `<p style="grid-column: 1 / -1; text-align: center; color: var(--text-muted);">No items found. Go farm some loot!</p>`;
    return;
  }

  const items = [
    {
      count: partA,
      name: "Grip",
      img: "bafkreiaheg5mug44s7yon5euap5yhrknsitotfvxpjnuimgs4hm3637ape",
      class: "",
    },
    {
      count: partB,
      name: "Blade",
      img: "bafkreidyhdg6v5oby5jutg5aka56se3iioxfh7u5rnip6minbd5girkl6u",
      class: "",
    },
    {
      count: sword,
      name: "Legendary Sword",
      img: "bafkreies4xxqnpg73aoqlcnjk4xr2hwapvnus4ertur76meq6a6t3yzae4",
      class: "legendary",
    },
  ];

  items.forEach((item) => {
    for (let i = 0; i < item.count; i++) {
      const card = document.createElement("div");
      card.className = `item-card glass-card ${item.class}`;
      card.innerHTML = `
                <div class="item-icon">
                    <img src="https://ipfs.io/ipfs/${item.img}" alt="${
        item.name
      }" style="max-height: 80px; border-radius: 8px;">
                </div>
                <h3>${item.name}</h3>
                <p style="font-size: 0.8em; color: var(--text-muted); margin-top: 5px;">Unit #${
                  i + 1
                }</p>
            `;
      container.appendChild(card);
    }
  });
}

const STATE_STRINGS = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed",
];

async function loadProposals() {
  try {
    const container = document.getElementById("proposalsContainer");
    container.innerHTML =
      '<p style="text-align: center;">Loading proposals...</p>';

    const filter = contracts.governor.filters.ProposalCreated();
    // Look back 10000 blocks to find proposals. On Anvil, 0 to latest is fine.
    const events = await contracts.governor.queryFilter(filter, 0, "latest");

    if (events.length === 0) {
      container.innerHTML =
        '<p style="text-align: center; color: var(--text-muted);">No proposals found.</p>';
      return;
    }

    container.innerHTML = "";

    // Render events in reverse chronological order
    for (let i = events.length - 1; i >= 0; i--) {
      const event = events[i];
      const { proposalId, description } = event.args;
      const state = await contracts.governor.state(proposalId);
      const stateStr = STATE_STRINGS[state] || "Unknown";
      const votes = await contracts.governor.proposalVotes(proposalId);

      const card = document.createElement("div");
      card.className = "proposal-card glass-card";
      card.innerHTML = `
                <div class="proposal-header">
                    <h4 style="word-break: break-all;">Proposal ID: ${proposalId
                      .toString()
                      .substring(0, 10)}...</h4>
                    <span class="status badge ${
                      stateStr === "Active" ? "active" : ""
                    }">${stateStr}</span>
                </div>
                <p><strong>Description:</strong> ${description}</p>
                <div style="font-size: 0.9em; margin-bottom: 10px;">
                    <span style="color: green;">For: ${ethers.utils.formatEther(
                      votes.forVotes
                    )}</span> | 
                    <span style="color: red;">Against: ${ethers.utils.formatEther(
                      votes.againstVotes
                    )}</span>
                </div>
                <div class="action-group">
                    <button class="btn secondary-btn" onclick="voteProposal('${proposalId.toString()}', 1)" ${
        state !== 1 ? "disabled" : ""
      }>Vote For</button>
                    <button class="btn danger-btn" onclick="voteProposal('${proposalId.toString()}', 0)" ${
        state !== 1 ? "disabled" : ""
      }>Vote Against</button>
                </div>
                <div class="action-group mt-2">
                    <button class="btn secondary-btn" onclick="queueProposal('${proposalId.toString()}', '${description}')" ${
        state !== 4 ? "disabled" : ""
      }>Queue (Succeeded)</button>
                    <button class="btn primary-btn glow-effect" onclick="executeProposal('${proposalId.toString()}', '${description}')" ${
        state !== 5 ? "disabled" : ""
      }>Execute (Queued)</button>
                </div>
            `;
      container.appendChild(card);
    }
  } catch (e) {
    console.error("Error loading proposals", e);
  }
}

// Global function for voting so inline onclick works
window.voteProposal = async function (proposalIdStr, support) {
  try {
    const tx = await contracts.governor.castVote(
      ethers.BigNumber.from(proposalIdStr),
      support
    );
    await tx.wait();
    alert("Vote cast successfully!");
    loadProposals();
    loadUserData();
  } catch (e) {
    console.error(e);
    alert("Error casting vote: " + (e.reason || e.message));
  }
};

// Helper to recreate calldata for queue/execute based on description parsing
// We hardcoded the proposal to always target GameEngine.setDropChance(bps)
// So we extract the bps from the description "Update Drop Chance to X bps"
function getProposalDataFromDescription(description) {
  const bpsMatch = description.match(/Update Drop Chance to (\d+) bps/);
  if (!bpsMatch) throw new Error("Could not parse proposal description");
  const bps = parseInt(bpsMatch[1]);

  const iface = new ethers.utils.Interface(["function setDropChance(uint256)"]);
  const calldata = iface.encodeFunctionData("setDropChance", [bps]);

  return {
    targets: [CONTRACT_ADDRESSES.GameEngine],
    values: [0],
    calldatas: [calldata],
    descriptionHash: ethers.utils.id(description), // keccak256
  };
}

window.queueProposal = async function (proposalIdStr, description) {
  try {
    const { targets, values, calldatas, descriptionHash } =
      getProposalDataFromDescription(description);
    const tx = await contracts.governor.queue(
      targets,
      values,
      calldatas,
      descriptionHash
    );
    await tx.wait();
    alert("Proposal Queued successfully!");
    loadProposals();
  } catch (e) {
    console.error(e);
    alert("Error queueing: " + (e.reason || e.message));
  }
};

window.executeProposal = async function (proposalIdStr, description) {
  try {
    const { targets, values, calldatas, descriptionHash } =
      getProposalDataFromDescription(description);
    const tx = await contracts.governor.execute(
      targets,
      values,
      calldatas,
      descriptionHash
    );
    await tx.wait();
    alert("Proposal Executed successfully!");
    loadProposals();
  } catch (e) {
    console.error(e);
    alert("Error executing: " + (e.reason || e.message));
  }
};

// Bind Button Actions
function bindContractActions() {
  // Farm Loot
  document.getElementById("farmBtn").addEventListener("click", async () => {
    const loops = document.getElementById("farmLoops").value;
    try {
      const tx = await contracts.gameEngine.farmLoot(loops);
      await tx.wait();
      alert("Loot farmed successfully!");
      loadUserData();
    } catch (e) {
      console.error(e);
      alert("Farming failed.");
    }
  });

  // AMM Swap
  document.getElementById("swapBtn").addEventListener("click", async () => {
    const tokenInSymbol = document.getElementById("swapTokenIn").value;
    const amount = ethers.utils.parseEther(
      document.getElementById("swapAmount").value || "0"
    );
    if (amount.eq(0)) return;

    try {
      const tokenInContract =
        tokenInSymbol === "GOV" ? contracts.govToken : contracts.ironToken;

      // Approve
      const approveTx = await tokenInContract.approve(
        CONTRACT_ADDRESSES.AMM,
        amount
      );
      await approveTx.wait();

      // Swap
      const tx = await contracts.amm.swap(tokenInContract.address, amount, 0); // 0 minAmountOut for demo
      await tx.wait();
      alert("Swap successful!");
      loadUserData();
    } catch (e) {
      console.error(e);
      alert("Swap failed.");
    }
  });

  // Craft Sword: Approve then Craft
  document
    .getElementById("approveCraftBtn")
    .addEventListener("click", async () => {
      try {
        const tx = await contracts.ironToken.approve(
          CONTRACT_ADDRESSES.GameItems,
          ethers.constants.MaxUint256
        );
        await tx.wait();
        alert("Approved GameItems to spend IRON!");
      } catch (e) {
        console.error(e);
      }
    });

  document.getElementById("craftBtn").addEventListener("click", async () => {
    try {
      const tx = await contracts.gameItems.craftSword();
      await tx.wait();
      alert("Legendary Sword Crafted!");
      loadUserData();
    } catch (e) {
      console.error(e);
      alert("Crafting failed. Did you approve IRON?");
    }
  });

  // Vault: Approve then Deposit
  document
    .getElementById("approveVaultBtn")
    .addEventListener("click", async () => {
      try {
        const amount = ethers.utils.parseEther(
          document.getElementById("depositAmount").value || "0"
        );
        const tx = await contracts.ironToken.approve(
          CONTRACT_ADDRESSES.IronVault,
          amount
        );
        await tx.wait();
        document.getElementById("depositVaultBtn").disabled = false;
        alert("Approved Vault to spend IRON!");
      } catch (e) {
        console.error(e);
      }
    });

  document
    .getElementById("depositVaultBtn")
    .addEventListener("click", async () => {
      try {
        const amount = ethers.utils.parseEther(
          document.getElementById("depositAmount").value || "0"
        );
        const tx = await contracts.vault.deposit(amount, userAddress);
        await tx.wait();
        alert("Deposited successfully!");
        loadUserData();
      } catch (e) {
        console.error(e);
        alert("Deposit failed.");
      }
    });

  document
    .getElementById("withdrawVaultBtn")
    .addEventListener("click", async () => {
      try {
        const shares = ethers.utils.parseEther(
          document.getElementById("withdrawAmount").value || "0"
        );
        const tx = await contracts.vault.withdraw(
          shares,
          userAddress,
          userAddress
        );
        await tx.wait();
        alert("Withdrawn successfully!");
        loadUserData();
      } catch (e) {
        console.error(e);
        alert("Withdraw failed.");
      }
    });

  // Shop Buy
  const buyIronInput = document.getElementById("buyIronAmount");
  const payEthInput = document.getElementById("payEthAmount");

  // Auto-calculate 1:1 ratio
  buyIronInput.addEventListener("input", (e) => {
    payEthInput.value = e.target.value;
  });

  document.getElementById("buyIronBtn").addEventListener("click", async () => {
    try {
      const ethAmount = ethers.utils.parseEther(payEthInput.value || "0");
      if (ethAmount.eq(0)) return;

      const tx = await contracts.shop.buyIron({ value: ethAmount });
      await tx.wait();
      alert("IRON purchased successfully!");
      loadUserData();
    } catch (error) {
      console.error(error);
      alert("Failed to buy IRON");
    }
  });

  // Governance
  document.getElementById("delegateBtn").addEventListener("click", async () => {
    try {
      const tx = await contracts.govToken.delegate(userAddress);
      await tx.wait();
      alert("Delegated successfully!");
      loadUserData();
    } catch (e) {
      console.error(e);
      alert("Delegation failed.");
    }
  });

  document
    .getElementById("createProposalBtn")
    .addEventListener("click", async () => {
      try {
        const bpsStr = document.getElementById("proposalDropChance").value;
        if (!bpsStr) return alert("Enter drop chance");

        const bps = parseInt(bpsStr);
        if (bps > 10000 || bps < 0) return alert("Must be between 0 and 10000");

        // Function selector for setDropChance(uint256)
        const iface = new ethers.utils.Interface([
          "function setDropChance(uint256)",
        ]);
        const calldata = iface.encodeFunctionData("setDropChance", [bps]);

        const targets = [CONTRACT_ADDRESSES.GameEngine];
        const values = [0];
        const calldatas = [calldata];
        const description = `Update Drop Chance to ${bps} bps`;

        const tx = await contracts.governor.propose(
          targets,
          values,
          calldatas,
          description
        );
        await tx.wait();
        alert("Proposal created successfully!");
        loadProposals();
      } catch (error) {
        console.error(error);
        alert("Failed to create proposal: " + (error.reason || error.message));
      }
    });

  document
    .getElementById("refreshProposalsBtn")
    .addEventListener("click", async () => {
      await loadProposals();
    });
}
