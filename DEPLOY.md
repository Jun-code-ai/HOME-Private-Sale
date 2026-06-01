# HOME 豪门 — Private Sale Deployment Guide

## Overview

This is a **real Web3 presale** on **BNB Smart Chain** accepting **USDT (BEP-20)**.

### Stack
| Layer | Technology |
|---|---|
| Smart Contract | Solidity ^0.8.19 |
| Chain | BSC Mainnet (Chain 56) |
| Accepted Token | USDT (0x55d398326f99059fF775485246999027B3197955) |
| Frontend | HTML + Tailwind CSS + ethers.js v6 |
| Wallet Support | TokenPocket, MetaMask, OKX, WalletConnect |

---

## Step 1: Deploy the Smart Contract

### Option A: Remix IDE (Easiest)

1. Go to https://remix.ethereum.org
2. Create `contracts/HOMEPresale.sol` with the content from `contracts/HOMEPresale.sol`
3. Compile with Solidity 0.8.19
4. Deploy via **Injected Provider** (MetaMask) on **BSC Mainnet**
5. Constructor parameters:
   - `_usdt`: `0x55d398326f99059fF775485246999027B3197955`
   - `_treasuryWallet`: **YOUR WALLET ADDRESS** (where funds go)

### Option B: Hardhat (Advanced)

```bash
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npx hardhat init
# Copy HOMEPresale.sol to contracts/
# Configure hardhat.config.js for BSC
npx hardhat compile
npx hardhat run scripts/deploy.js --network bsc
```

### After deploying, save:
- **Contract Address**: `0x...`
- **Transaction Hash**: `0x...`

---

## Step 2: Verify Contract on BscScan

1. Go to https://bscscan.com/address/YOUR_CONTRACT_ADDRESS
2. Click "Verify and Publish"
3. Use:
   - Compiler: Solidity 0.8.19
   - Optimization: Yes (200 runs)
   - License: MIT

---

## Step 3: Update Frontend

In `index.html`, find and replace:

```javascript
const PRESALE_CONTRACT_ADDRESS = '0x_YOUR_DEPLOYED_CONTRACT_ADDRESS_HERE_';
```

With your deployed contract address.

---

## Step 4: Deploy Frontend

### Option A: Vercel (Recommended)
```bash
npx vercel
```

### Option B: GitHub Pages
1. Push to GitHub
2. Settings → Pages → Deploy from branch `master`

### Option C: Any static host
Upload `index.html` to any web server.

---

## Smart Contract Features

| Feature | Detail |
|---|---|
| Token | USDT (BEP-20) on BSC |
| Soft Cap | 500,000 USDT |
| Hard Cap | 1,000,000 USDT |
| Seed Tier | $0.08/token, 30% bonus, 1k-50k USDT |
| Private Tier | $0.10/token, 15% bonus, 500-30k USDT |
| Public Tier | $0.15/token, 5% bonus, 100-10k USDT |

## User Flow

1. User visits landing page
2. Clicks "Login with TP Wallet" → connects wallet
3. Page auto-switches to BSC network
4. User clicks "Buy Private" → enters USDT amount
5. Step 1: User approves USDT spending
6. Step 2: User confirms contribution transaction
7. Contract transfers USDT to your treasury wallet
8. Dashboard shows live contribution data

## Owner Functions

Callable only by the deploying wallet:
- `updateCaps(softCap, hardCap)` — Adjust caps
- `updateTier(key, price, bonus, min, max, maxContributors)` — Modify tier
- `togglePresale()` — Pause/Resume
- `withdrawBNB()` — Recover accidentally sent BNB
- `recoverToken(address)` — Recover non-USDT tokens

## Important Notes

- **USDT requires `approve()` first** — users must approve the contract to spend USDT before contributing
- **BSC gas fees are paid in BNB** — make sure users have BNB for gas
- **Test on Testnet first** — deploy to BSC Testnet (Chain 97) and test the full flow
- **Audit recommended** — get a professional audit before mainnet launch
