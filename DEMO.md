# 🚀 VeloHooks Demo Guide

This guide will walk you through demonstrating the **Uniswap v4 Reactive Loyalty Hook**. You will deploy the contracts, simulate user interactions, and trigger cross-chain milestones.

## 🛠 Prerequisites

- [Foundry](https://getfoundry.sh/) installed and updated.
- RPC URLs for Unichain Sepolia and Reactive Lasna (optional, can run locally).

## 📥 Setup

1. **Install Dependencies**:
   ```bash
   forge install
   ```

2. **Build Contracts**:
   ```bash
   forge build
   ```

3. **Configure Environment**:
   Ensure your `.env` is set up:
   ```bash
   PRIVATE_KEY=...
   UNICHAIN_PRIVATE_KEY=...
   REACTIVE_PRIVATE_KEY=...
   POOL_MANAGER=0x...
   ```

## 🚢 Deployment Flow

For a full demo, you need to deploy and link the system:

1. **Deploy to Unichain**:
   ```bash
   forge script script/DeployUnichain.s.sol --rpc-url <UNICHAIN_RPC> --broadcast
   ```

2. **Deploy to Reactive**:
   ```bash
   forge script script/DeployReactive.s.sol --rpc-url <REACTIVE_RPC> --broadcast
   ```

3. **Link Everything**:
   Update `LinkEverything.s.sol` with the deployed addresses and run:
   ```bash
   forge script script/LinkEverything.s.sol --rpc-url <UNICHAIN_RPC> --broadcast
   ```

## 🎮 Running the Interactive Demo

We have provided a specialized script to simulate the entire loyalty lifecycle in one go.

### Real-World On-Chain Demo (Anvil Only)

This version uses a real `PoolManager` and persistent on-chain state.

1. **Start Anvil**:
   ```bash
   anvil
   ```

2. **Execute Real-World Demo**:
   ```bash
   forge script script/RealWorldDemo.s.sol --rpc-url http://localhost:8545 --broadcast -vvvv --tc RealWorldDemo
   ```

### What the Real-World Demo Does:
- **Deploy**: Fresh Uniswap v4 `PoolManager` + Mock Tokens.
- **Hook Deployment**: Mines the correct `0x3FF0` salt to satisfy Uni v4 requirements.
- **Initialization**: Creates a real Pool with the hook.
- **True Transactions**: Uses an `InteractionHelper` to perform `unlock` callbacks, `modifyLiquidity`, and `swap` calls.
- **Persistence**: All state changes (points, balances) are recorded on the Anvil chain.

### What the Demo Does:
1. **Setup**: Mocks a `PoolManager` and deploys the Loyalty system.
2. **Liquidity Boost**: Alice adds liquidity and earns **1,000 points** (10x multiplier).
3. **Swap Rewards**: Alice performs an ETH swap and earns **10 points** (1x multiplier).
4. **Milestone Trigger**: The Reactive contract sets a **2x Global Multiplier** (e.g. "Happy Hour").
5. **Boosted Swap**: Alice swaps again and earns **20 points** (2x multiplier).
6. **Tier Achievement**: Alice reaches the **Gold Tier** (5,000+ points) to unlock a **2x per-user boost**.
7. **Redemption**: Alice redeems points for **Loyalty Tokens (LTK)**.

## 📊 Verification

Check the console output for these key logs:
- `Alice Points: 1010` (Initial points)
- `Alice Points after Milestone: 1030` (Boosted points)
- `Alice LTK Balance: 50.000...` (Successful redemption)

---
*Built with ❤️ for the VeloHooks Demo*
