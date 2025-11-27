# DApp Setup (Rookie-friendly)

This repo bootstraps a modern DApp workspace:

- **Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4
- **Contracts**: Hardhat v3 (ESM) + toolbox-viem, **OpenZeppelin**, **Foundry (Forge/Anvil)**
- **DX**: TypeChain, hardhat-deploy, gas reporter, contract sizer, docgen, Solhint/Prettier, Husky hooks
- **CI**: GitHub Actions (compile, test, lint)

---

## 1) First-time setup

Run the setup script:
```bash
bash setup.sh
```

After setup completes, you'll need to configure your environment files:

**Step 1:** Edit `apps/dao-dapp/.env.local`
- Add your `VITE_WALLETCONNECT_ID` (get one free from [WalletConnect Cloud](https://cloud.walletconnect.com))
- Add RPC URLs for the networks you want to use (defaults are provided)

**Step 2:** Edit `packages/contracts/.env.hardhat.local`
- Add your `PRIVATE_KEY` or `MNEMONIC` (for deploying contracts)
- Add RPC URLs for networks (Sepolia, Mainnet, etc.)
- Add `ETHERSCAN_API_KEY` (get one free from [Etherscan](https://etherscan.io/apis))
- Optionally add `CMC_API_KEY` for gas price reporting

**Optional speedup:** If you want faster builds, run:
```bash
pnpm approve-builds
# Then select: bufferutil, utf-8-validate, keccak, secp256k1
```

## Next Steps After Setup

1. **Edit apps/dao-dapp/.env.local** - Add your WalletConnect ID and RPC URLs
2. **Edit packages/contracts/.env.hardhat.local** - Add your private key/mnemonic and API keys
3. **To deploy the website locally**, run `pnpm web:dev` from the root directory
4. **To deploy the app online**, follow the detailed steps below

## Deploy Your App Online

### Step 1: Create a GitHub repository
- Go to https://github.com and sign in (or create a free account)
- Click the '+' icon in the top right corner → 'New repository'
- Name your repository (e.g., 'my-dao-dapp')
- Choose 'Public' or 'Private'
- **DO NOT initialize with README, .gitignore, or license** (we already have these)
- Click 'Create repository'

### Step 2: Sync your project to GitHub
- In your terminal, make sure you're in the project root folder
- Check if git is initialized: `git status`
- If not initialized, run: `git init`
- Add your GitHub repo as remote: `git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git`
  (Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual GitHub username and repo name)
- Stage all files: `git add -A`
- Commit: `git commit -m 'Initial commit'`
- Push to GitHub: `git push -u origin main`
- Refresh your GitHub page - you should see all your files there!

### Step 3: Set up Fleek and configure deployment
- Go to https://app.fleek.co and sign in (or create a free account)
- Click 'Create new - site'
- Select code location **GitHub**
- Authorize Fleek to access your GitHub account (click 'Authorize')
- Select your repository from the list and click 'Deploy'
- Select the 'main' branch (or your default branch name)
- On the same configuration page, you'll see these fields:
  * **'Framework'**: Select 'Vite' from the dropdown (or 'Other' if Vite is not available)
  * **'Branch'**: Should already show 'main' (or your default branch)
  * **'Publish Directory'**: Enter `apps/dao-dapp/dist`
  * **'Build Command'**: Enter `corepack enable && corepack prepare pnpm@10.16.1 --activate && pnpm install --frozen-lockfile=false && pnpm web:build`
    (This enables Corepack, sets up pnpm, installs dependencies, then builds your app)
    (The build creates the 'dist' folder that Fleek will deploy)
  * Under advanced options, **'Docker Image'**: Change from 'fleek/node:lts' to 'node:22'
    (This ensures Node.js version 22 is used, which your project requires)
    (If 'node:22' doesn't work, try 'fleek/node:22' or check Fleek docs for Node 22 image)
  * **'Base Directory'**: Leave as './' (or click 'Select' and choose the project root)
- Scroll down to the 'Environment Variables' section (on the same page)
- **IMPORTANT**: Add these environment variables **BEFORE** clicking 'Deploy site'
- Click 'Add Variable' or '+' button for each variable
- Add these variables one by one (get values from your `apps/dao-dapp/.env.local` file):
  * **Name**: `VITE_WALLETCONNECT_ID`
    **Value**: (get one free from https://cloud.walletconnect.com - sign up and create a project)
  * **Name**: `VITE_MAINNET_RPC`
    **Value**: `https://cloudflare-eth.com` (or your custom RPC)
  * **Name**: `VITE_POLYGON_RPC`
    **Value**: `https://polygon-rpc.com` (or your custom RPC)
  * **Name**: `VITE_OPTIMISM_RPC`
    **Value**: `https://optimism.publicnode.com` (or your custom RPC)
  * **Name**: `VITE_ARBITRUM_RPC`
    **Value**: `https://arbitrum.publicnode.com` (or your custom RPC)
  * **Name**: `VITE_SEPOLIA_RPC`
    **Value**: `https://rpc.sepolia.org` (or your custom RPC)
- (If you see 'Hide advanced options', click it to see more fields if needed)

### Step 4: Deploy manually (first time)
- Click 'Deploy Site' or 'Deploy' button at the bottom of the Fleek page
- Wait for the build to complete (you'll see progress in Fleek dashboard)
- Once done, you'll get a URL like: `your-site.on.fleek.co`
- Your app is now live! Share the URL with anyone 🌐

**Troubleshooting: If deployment fails or website is blank:**
- Go to your site in Fleek dashboard → 'Deployments' tab
- Click on the failed deployment to see details
- Click on 'Build Logs' step to see error messages
- Common issues and fixes:
  * **If website deploys but shows blank page:**
    → Go to Settings → Environment Variables
    → Make sure all VITE_* variables are added (especially VITE_WALLETCONNECT_ID)
    → Redeploy after adding missing variables
  * **If you see 'Unsupported engine' or wrong Node version:**
    → Go to Settings → Make sure 'Docker Image' is set to 'fleek/node:22' or 'node:22'
  * **If you see 'tsc: not found' or 'node_modules missing':**
    → Make sure 'Build Command' includes all steps: `corepack enable && corepack prepare pnpm@10.16.1 --activate && pnpm install --frozen-lockfile=false && pnpm web:build`
  * **If you see 'Dist directory does not exist' AFTER build completes:**
    → Check that 'Publish Directory' is exactly `apps/dao-dapp/dist` (not just 'dist')
    → Check that 'Base Directory' is './' (project root)
    → The build command should CREATE the dist folder - if it doesn't exist, the build failed
- After fixing, click 'Redeploy' button to try again

### Step 5: Set up automatic deployment via GitHub Actions (optional but recommended)
- This allows your app to auto-deploy when you push code to GitHub
- Go to https://app.fleek.co → Your site → Settings → API Keys
- Click 'Generate API Key' or copy your existing API key
- Go to your GitHub repository page
- Click 'Settings' tab (top menu)
- In the left sidebar, click 'Secrets and variables' → 'Actions'
- Click 'New repository secret' button
- **Name**: `FLEEK_API_KEY`
- **Value**: Paste the API key you copied from Fleek
- Click 'Add secret'
- Now go to your project folder in terminal
- Navigate to apps/dao-dapp: `cd apps/dao-dapp`
- Run: `pnpm dlx @fleekhq/fleek-cli@0.1.8 site:init`
- This creates a `.fleek.json` file
- Go back to project root: `cd ../..`
- Commit and push: `git add apps/dao-dapp/.fleek.json && git commit -m 'Add Fleek config' && git push`
- Now every time you push to main branch, GitHub Actions will automatically deploy your app!

---

## 2) Everyday commands

**Frontend**

```bash
pnpm web:dev       # run the React app
pnpm web:build     # production build
pnpm web:preview   # preview the build
```

**Local chain**

```bash
pnpm anvil:start   # start local EVM at http://127.0.0.1:8545
pnpm anvil:stop    # stop anvil
```

**Contracts (Hardhat)**

```bash
pnpm contracts:compile
pnpm contracts:test
pnpm contracts:deploy
pnpm contracts:verify 0xYourContractAddress
```

**Contracts (Foundry)**

```bash
pnpm forge:test    # very fast tests + fuzzing
pnpm forge:fmt     # format Solidity
pnpm foundry:update # update Foundry tools
```

Husky will auto-run formatting/lint for TS/Solidity on each commit.

---

## 3) Adding contracts (OpenZeppelin)

Create a new file under `packages/contracts/contracts/`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
```

**Deploy** via `hardhat-deploy`: create `packages/contracts/deploy/01_mytoken.ts`:

```ts
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  await deploy('MyToken', { from: deployer, args: [], log: true })
}
export default func
func.tags = ['MyToken']
```

Run:

```bash
pnpm contracts:compile
pnpm --filter contracts exec hardhat deploy --network sepolia --tags MyToken
```

Artifacts (ABIs, addresses) are exported to `apps/dao-dapp/src/contracts/` for the frontend.

---

## 4) Frontend usage (wagmi)

Inside `apps/dao-dapp`, you can import your ABI (from `src/contracts`) and use wagmi hooks:

```ts
import { Address, createConfig } from 'wagmi'
import { readContract } from 'wagmi/actions'
```

(You already have `RainbowKit + wagmi` pre-wired through `src/config/wagmi.ts`.)

---

## 5) Gas, size, docs

* **Gas**: `hardhat-gas-reporter` prints gas & USD estimates on test runs.
* **Size**: `hardhat-contract-sizer` reports bytecode size on compile (helps avoid 24KB limit).
* **Docs**: `hardhat-docgen` is installed but disabled by default. Enable by uncommenting the import and config block in `hardhat.config.ts`.

---

## 6) Linting & formatting

* **Solidity**: `solhint` + `prettier-plugin-solidity`
* **TS/JS**: `eslint` + `prettier`
* **Hooks**: Husky runs fixes on commit; CI runs lint and tests on PRs.

---

## 7) Static analysis (optional)

Install Slither locally (recommended):

```bash
# install pipx first, then:
pipx install slither-analyzer
cd packages/contracts
slither .
```

---

## 8) Tips

* Prefer **Foundry** for fast unit + fuzz tests (`forge test`).
* Use **hardhat-deploy** for reproducible deployments and tagging.
* Keep upgradeable patterns safe (no constructors/immutables in implementation; use OZ Upgradeable if needed).
* Check the `docs/`, `gas`, and `size` outputs regularly to catch regressions early.

Happy shipping! 🚀
