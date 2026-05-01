# CharityChain

CharityChain is a Web3 charity platform built for Avalanche Fuji Testnet. It combines a plain HTML/CSS/JavaScript frontend with Solidity smart contracts for NGO verification, campaign creation, milestone voting, controlled fund release, and donor refunds.

## Live Deployment

- Production frontend: [https://charitychain-demo.vercel.app](https://charitychain-demo.vercel.app)
- Verified Fuji `CharityManager`: `0x436cb64A239a29b315a9B16deaC9b3737f762dce`
- Explorer: [https://testnet.snowtrace.io/address/0x436cb64A239a29b315a9B16deaC9b3737f762dce/contract/43113/code](https://testnet.snowtrace.io/address/0x436cb64A239a29b315a9B16deaC9b3737f762dce/contract/43113/code)

## Stack

- Solidity smart contracts
- Avalanche Fuji Testnet
- Ethers.js v5
- Plain HTML, CSS, and vanilla JavaScript
- Vercel for frontend hosting

## Main Features

- NGO application and admin verification flow
- Campaign factory via `CharityManager`
- Per-campaign milestone-based voting
- Weighted donor voting based on contribution size
- Controlled fund release to NGOs
- Refund support for failed, expired, or deadlocked campaigns
- 7-day voting period for milestone votes
- Campaign duration chosen by NGO in days at creation time

## Project Structure

- `contracts/` — finalized production Solidity contracts
- `scripts/compile.cjs` — local compile script
- `scripts/deploy.cjs` — Fuji deployment script
- `contracts.js` — frontend ABI and live manager address
- `index.html`, `explore.html`, `ngo.html`, `apply.html`, `admin.html` — main frontend pages
- `contract-variants/` — archived backups and alternative contract drafts kept for reference

## Smart Contracts

### `CharityManager.sol`

Factory and registry contract that:

- stores verified NGO records
- handles NGO applications, approval, and rejection
- creates new `CharityCampaign` contracts
- supports admin pause/unpause and two-step admin transfer

### `CharityCampaign.sol`

Per-campaign contract that:

- accepts donations while active
- tracks milestones and voting progress
- allows NGOs to start milestone voting after goal achievement
- lets donors vote once per voting round
- releases funds only after successful voting
- supports refunds after failed campaign outcomes

## Current Timing Rules

- Voting period: `7 days`
- Campaign duration: chosen by NGO in `days` during campaign creation

## Local Setup

Install dependencies:

```bash
npm install
```

Compile contracts:

```bash
npm run compile
```

Deploy to Fuji:

```bash
npm run deploy:fuji
```

To deploy, create a local `.env` file with:

```env
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
DEPLOYER_PRIVATE_KEY=your_private_key_here
```

Do not commit `.env` or any wallet secrets.

## Running the Frontend Locally

From the project directory:

```bash
python3 -m http.server 8080
```

Then open:

- `http://localhost:8080/index.html`
- `http://localhost:8080/explore.html`
- `http://localhost:8080/ngo.html`

## Notes

- This repository contains the finalized 7-day version of the platform.
- Each campaign is deployed as its own `CharityCampaign` contract through the verified `CharityManager`.
- The frontend is configured for Avalanche Fuji Testnet.
