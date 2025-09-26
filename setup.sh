#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup.sh — Node 22 + React 18 + wagmi/RainbowKit + Tailwind v4 + Hardhat 3 (ESM)
#           + OpenZeppelin + Foundry (Forge/Anvil) + TypeChain + HH plugins
#           + Solhint/Prettier + Husky + CI-ready DX
#
# Usage (from an EMPTY folder, or rerun safely to repair an existing setup):
#   bash setup.sh
#
# What you get:
# - apps/dao-dapp : Vite + React 18 + RainbowKit v2 + wagmi v2 + TanStack Query v5 + Tailwind v4
# - packages/contracts : Hardhat v3 (ESM) + toolbox-viem + OpenZeppelin + Foundry (Forge/Anvil)
# - TypeChain, hardhat-deploy, gas reporter, contract sizer, docgen
# - Solhint + prettier-plugin-solidity + Husky pre-commit guardrails
# - README.md with rookie-friendly instructions
#
# After it finishes:
#   1) Edit apps/dao-dapp/.env.local  (VITE_WALLETCONNECT_ID + RPCs)
#   2) Edit packages/contracts/.env.hardhat.local  (PRIVATE_KEY/MNEMONIC + RPCs + ETHERSCAN key)
#   3) (Optional) Approve native builds for speed: pnpm approve-builds
#      -> select: bufferutil, utf-8-validate, keccak, secp256k1
#   4) Compile contracts: pnpm contracts:compile
#   5) Start web app:     pnpm web:dev
# -----------------------------------------------------------------------------

# --- Corepack & pnpm ---------------------------------------------------------------
command -v corepack >/dev/null 2>&1 || {
  echo "Corepack not found. Install Node.js >= 22 and retry." >&2
  exit 1
}
corepack enable
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack prepare pnpm@10.16.1 --activate

# Pin Node 22 for dev shells
printf "v22\n" > .nvmrc

# --- Root files --------------------------------------------------------------------
mkdir -p .github/workflows

cat > .gitignore <<'EOF'
node_modules
dist
.env
.env.*
packages/contracts/cache
packages/contracts/artifacts
packages/contracts/typechain-types
packages/contracts/.env.hardhat.local
apps/dao-dapp/src/contracts/*
!apps/dao-dapp/src/contracts/.gitkeep
EOF

# Root package.json (idempotent overwrite)
cat > package.json <<'EOF'
{
  "name": "dapp_setup",
  "private": true,
  "packageManager": "pnpm@10.16.1",
  "engines": { "node": ">=22 <23" },
  "scripts": {
    "web:dev": "pnpm --dir apps/dao-dapp dev",
    "web:build": "pnpm --dir apps/dao-dapp build",
    "web:preview": "pnpm --dir apps/dao-dapp preview",

    "contracts:compile": "pnpm --filter contracts run compile",
    "contracts:test": "pnpm --filter contracts run test",
    "contracts:deploy": "pnpm --filter contracts run deploy",
    "contracts:verify": "pnpm --filter contracts exec hardhat verify",

    "anvil": "anvil --block-time 1",
    "forge:test": "forge test -vvv",
    "forge:fmt": "forge fmt"
  }
}
EOF

cat > pnpm-workspace.yaml <<'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF

# --- App scaffold (Vite + React + TS) ----------------------------------------------
mkdir -p apps
if [ -d "apps/dao-dapp" ]; then
  echo "apps/dao-dapp already exists; keeping it and ensuring deps/configs are correct."
else
  pnpm create vite@6 apps/dao-dapp -- --template react-ts --no-git --package-manager pnpm
fi

# Force React 18 (web3 peers target <=18)
pnpm --dir apps/dao-dapp add react@18.3.1 react-dom@18.3.1
pnpm --dir apps/dao-dapp add -D @types/react@18.3.12 @types/react-dom@18.3.1

# Web3 + data
pnpm --dir apps/dao-dapp add @rainbow-me/rainbowkit@~2.2.8 wagmi@~2.16.9 viem@~2.37.6 @tanstack/react-query@~5.89.0
pnpm --dir apps/dao-dapp add @tanstack/react-query-devtools zod

# Tailwind v4 (PostCSS plugin)
pnpm --dir apps/dao-dapp add -D tailwindcss@~4.0.0 @tailwindcss/postcss@~4.0.0 postcss@~8.4.47

# postcss.config (ESM)
cat > apps/dao-dapp/postcss.config.mjs <<'EOF'
export default { plugins: { '@tailwindcss/postcss': {} } }
EOF

# Tailwind entry
mkdir -p apps/dao-dapp/src
cat > apps/dao-dapp/src/index.css <<'EOF'
@import "tailwindcss";
EOF

# Contracts artifacts bucket (consumed by the app)
mkdir -p apps/dao-dapp/src/contracts
cat > apps/dao-dapp/src/contracts/.gitkeep <<'EOF'
# Generated contract artifacts are ignored by git but kept for tooling.
EOF

# Wagmi/RainbowKit config (HTTP only)
mkdir -p apps/dao-dapp/src/config
cat > apps/dao-dapp/src/config/wagmi.ts <<'EOF'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { mainnet, polygon, optimism, arbitrum, sepolia } from 'wagmi/chains'
import { http } from 'wagmi'

export const config = getDefaultConfig({
  appName: 'DAO dApp',
  projectId: import.meta.env.VITE_WALLETCONNECT_ID!,
  chains: [mainnet, polygon, optimism, arbitrum, sepolia],
  transports: {
    [mainnet.id]: http(import.meta.env.VITE_MAINNET_RPC!),
    [polygon.id]: http(import.meta.env.VITE_POLYGON_RPC!),
    [optimism.id]: http(import.meta.env.VITE_OPTIMISM_RPC!),
    [arbitrum.id]: http(import.meta.env.VITE_ARBITRUM_RPC!),
    [sepolia.id]: http(import.meta.env.VITE_SEPOLIA_RPC!)
  },
  ssr: false
})
EOF

# main.tsx providers (overwrite to ensure stable setup)
cat > apps/dao-dapp/src/main.tsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RainbowKitProvider } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'

import { config } from './config/wagmi'
import App from './App'
import './index.css'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const qc = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={qc}>
        <RainbowKitProvider>
          <App />
          {import.meta.env.DEV && <ReactQueryDevtools initialIsOpen={false} />}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
)
EOF

# Minimal App (overwrite harmlessly)
cat > apps/dao-dapp/src/App.tsx <<'EOF'
import { ConnectButton } from '@rainbow-me/rainbowkit'

export default function App() {
  return (
    <div className="min-h-screen p-6">
      <header className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">DAO dApp</h1>
        <ConnectButton />
      </header>
    </div>
  )
}
EOF

# Env example + local
cat > apps/dao-dapp/.env.example <<'EOF'
VITE_WALLETCONNECT_ID=
VITE_MAINNET_RPC=https://cloudflare-eth.com
VITE_POLYGON_RPC=https://polygon-rpc.com
VITE_OPTIMISM_RPC=https://optimism.publicnode.com
VITE_ARBITRUM_RPC=https://arbitrum.publicnode.com
VITE_SEPOLIA_RPC=https://rpc.sepolia.org
EOF
cp -f apps/dao-dapp/.env.example apps/dao-dapp/.env.local

# Ensure app node_modules present
pnpm --dir apps/dao-dapp install

# --- Contracts workspace (Hardhat 3 + toolbox-viem + TS, ESM) ---------------------
mkdir -p packages/contracts

# contracts/package.json — ESM required by Hardhat 3
cat > packages/contracts/package.json <<'EOF'
{
  "name": "contracts",
  "private": true,
  "type": "module",
  "scripts": {
    "clean": "hardhat clean",
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat deploy",
    "deploy:tags": "hardhat deploy --tags all",
    "verify": "hardhat etherscan-verify"
  }
}
EOF

# tsconfig — NodeNext/ESM
cat > packages/contracts/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "moduleResolution": "NodeNext",
    "resolveJsonModule": true,
    "outDir": "dist",
    "types": ["node", "hardhat"]
  },
  "include": ["hardhat.config.ts", "scripts", "test", "typechain-types"],
  "exclude": ["dist"]
}
EOF

# hardhat.config.ts — ESM-safe __dirname + toolbox-viem + plugins + HH3 "type"
cat > packages/contracts/hardhat.config.ts <<'EOF'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { config as loadEnv } from 'dotenv'
import type { HardhatUserConfig } from 'hardhat/config'

import '@nomicfoundation/hardhat-toolbox-viem'
import 'hardhat-typechain'
import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'hardhat-contract-sizer'
import 'hardhat-docgen'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

loadEnv({ path: resolve(__dirname, '.env.hardhat.local') })

const privateKey = process.env.PRIVATE_KEY?.trim()
const mnemonic = process.env.MNEMONIC?.trim()
const accounts = privateKey ? [privateKey] : mnemonic ? { mnemonic } : undefined

// Hardhat v3 requires a "type" discriminator on each network
const networks: any = {
  hardhat: { type: 'edr-simulated' }
}

const addHttp = (name: string, url?: string) => {
  const u = url?.trim()
  if (!u) return
  networks[name] = { type: 'http', url: u, ...(accounts ? { accounts } : {}) }
}

addHttp('mainnet', process.env.MAINNET_RPC)
addHttp('polygon', process.env.POLYGON_RPC)
addHttp('optimism', process.env.OPTIMISM_RPC)
addHttp('arbitrum', process.env.ARBITRUM_RPC)
addHttp('sepolia', process.env.SEPOLIA_RPC)

const config: HardhatUserConfig = {
  solidity: { version: '0.8.28', settings: { optimizer: { enabled: true, runs: 200 } } },
  defaultNetwork: 'hardhat',
  networks,
  verify: { etherscan: { apiKey: process.env.ETHERSCAN_API_KEY || '' } },
  namedAccounts: { deployer: { default: 0 } },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    coinmarketcap: process.env.CMC_API_KEY || undefined
  },
  contractSizer: {
    runOnCompile: true,
    alphaSort: true,
    disambiguatePaths: false
  },
  docgen: {
    outputDir: './docs',
    pages: 'items',
    collapseNewlines: true
  },
  paths: {
    root: resolve(__dirname),
    sources: resolve(__dirname, 'contracts'),
    tests: resolve(__dirname, 'test'),
    cache: resolve(__dirname, 'cache'),
    artifacts: resolve(__dirname, '../../apps/dao-dapp/src/contracts')
  }
}

export default config
EOF

# Contracts dirs and placeholders
mkdir -p packages/contracts/contracts
cat > packages/contracts/contracts/.gitkeep <<'EOF'
# Add your Solidity contracts here.
EOF

mkdir -p packages/contracts/deploy
cat > packages/contracts/deploy/00_sample.ts <<'EOF'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  // Example deployment placeholder:
  // await deploy('MyContract', { from: deployer, args: [], log: true })
  console.log('No contracts to deploy yet.')
}
export default func
func.tags = ['all']
EOF

mkdir -p packages/contracts/scripts
cat > packages/contracts/scripts/deploy.ts <<'EOF'
async function main() {
  console.log('Implement deployments in packages/contracts/scripts/deploy.ts or use hardhat-deploy in /deploy.')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
EOF

mkdir -p packages/contracts/test
cat > packages/contracts/test/.gitkeep <<'EOF'
# Add your Hardhat tests here.
EOF

# .env examples
cat > packages/contracts/.env.hardhat.example <<'EOF'
# Private key or mnemonic for deployments (set one of the two)
PRIVATE_KEY=
MNEMONIC=

# RPC endpoints (HTTPS)
MAINNET_RPC=
POLYGON_RPC=
OPTIMISM_RPC=
ARBITRUM_RPC=
SEPOLIA_RPC=

# Block explorer API key (Etherscan family)
ETHERSCAN_API_KEY=

# CoinMarketCap API key (optional, for gas-reporter USD estimates)
CMC_API_KEY=
EOF
cp -f packages/contracts/.env.hardhat.example packages/contracts/.env.hardhat.local

# Dev deps for contracts (HH3 + toolbox-viem + TS + plugins + typechain)
pnpm --dir packages/contracts add -D hardhat@^3 @nomicfoundation/hardhat-toolbox-viem@^5.0.0 typescript@~5.9.2 ts-node@~10.9.2 @types/node@^22 dotenv@^16
pnpm --dir packages/contracts add -D typechain @typechain/ethers-v6 hardhat-typechain
pnpm --dir packages/contracts add -D hardhat-deploy hardhat-gas-reporter hardhat-contract-sizer hardhat-docgen

# **OpenZeppelin** (runtime dependencies)
pnpm --dir packages/contracts add @openzeppelin/contracts @openzeppelin/contracts-upgradeable

# Install workspace deps (root lockfile)
pnpm install

# --- Foundry (Forge/Anvil) ---------------------------------------------------------
# Install Foundry (idempotent). Skips if already installed.
if [ ! -x "$HOME/.foundry/bin/forge" ]; then
  curl -L https://foundry.paradigm.xyz | bash
  "$HOME/.foundry/bin/foundryup"
else
  "$HOME/.foundry/bin/foundryup"
fi

# foundry.toml and basic layout
cat > packages/contracts/foundry.toml <<'EOF'
[profile.default]
src = "contracts"
test = "forge-test"
out = "out"
libs = ["lib"]
solc_version = "0.8.28"
evm_version = "paris"
optimizer = true
optimizer_runs = 200
fs_permissions = [{ access = "read", path = "./" }]

[fuzz]
runs = 256

[invariant]
runs = 64
depth = 64
fail_on_revert = true
EOF

mkdir -p packages/contracts/forge-test
cat > packages/contracts/forge-test/Sample.t.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

contract SampleTest is Test {
    function test_truth() public {
        assertTrue(true);
    }
}
EOF

# --- Lint / Format (ESLint + Prettier + Solhint) -----------------------------------
pnpm add -D eslint prettier

pnpm --dir packages/contracts add -D solhint prettier prettier-plugin-solidity

cat > apps/dao-dapp/.eslintrc.json <<'EOF'
{
  "root": true,
  "env": { "browser": true, "es2022": true },
  "extends": ["eslint:recommended", "plugin:react-hooks/recommended"],
  "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" }
}
EOF

cat > .prettierrc.json <<'EOF'
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "overrides": [
    { "files": "*.sol", "options": { "plugins": ["prettier-plugin-solidity"] } }
  ]
}
EOF

cat > packages/contracts/.solhint.json <<'EOF'
{
  "extends": ["solhint:recommended"],
  "rules": {
    "func-visibility": ["error", { "ignoreConstructors": true }],
    "max-line-length": ["warn", 120]
  }
}
EOF

# --- Husky + lint-staged ------------------------------------------------------------
pnpm add -D husky lint-staged
pnpm dlx husky init

cat > .lintstagedrc.json <<'EOF'
{
  "*.{ts,tsx,js}": ["eslint --fix", "prettier --write"],
  "packages/contracts/**/*.sol": ["prettier --write", "solhint --fix"]
}
EOF

mkdir -p .husky
cat > .husky/pre-commit <<'EOF'
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
echo "Running lint-staged…"
pnpm dlx lint-staged
if command -v forge >/dev/null 2>&1; then
  forge fmt
fi
EOF
chmod +x .husky/pre-commit

# --- GitHub Actions (CI) ------------------------------------------------------------
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'pnpm'

      - run: corepack enable
      - run: corepack prepare pnpm@10.16.1 --activate

      - run: pnpm install

      - run: pnpm contracts:compile
      - run: pnpm --filter contracts test

      - name: Foundry tests
        run: |
          curl -L https://foundry.paradigm.xyz | bash
          ~/.foundry/bin/foundryup
          forge test -vvv
        working-directory: packages/contracts

      - run: pnpm dlx eslint apps/dao-dapp --ext .ts,.tsx
      - run: pnpm --filter contracts exec solhint 'contracts/**/*.sol' || true
EOF

# --- Slither (optional local install hint) ------------------------------------------
if command -v pipx >/dev/null 2>&1; then
  echo "Tip: install Slither with: pipx install slither-analyzer"
else
  echo "Tip: Install pipx, then 'pipx install slither-analyzer' to use Slither locally."
fi

# --- README (rookie-friendly guide) -------------------------------------------------
cat > README.md <<'EOF'
# DApp Setup (Rookie-friendly)

This repo bootstraps a modern DApp workspace:

- **Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4
- **Contracts**: Hardhat v3 (ESM) + toolbox-viem, **OpenZeppelin**, **Foundry (Forge/Anvil)**
- **DX**: TypeChain, hardhat-deploy, gas reporter, contract sizer, docgen, Solhint/Prettier, Husky hooks
- **CI**: GitHub Actions (compile, test, lint)

---

## 1) First-time setup

```bash
# Make a new folder, copy setup.sh, then:
bash setup.sh
```

Fill in env files:

* `apps/dao-dapp/.env.local`

  * `VITE_WALLETCONNECT_ID=...`
  * RPC URLs (mainnet/polygon/optimism/arbitrum/sepolia)

* `packages/contracts/.env.hardhat.local`

  * `PRIVATE_KEY=` or `MNEMONIC=`
  * `SEPOLIA_RPC=...` (and others you use)
  * `ETHERSCAN_API_KEY=...` (for verification)
  * optional `CMC_API_KEY=` (gas reporter USD)

Optional native speedups:

```bash
pnpm approve-builds
# select: bufferutil, utf-8-validate, keccak, secp256k1
```

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
pnpm anvil         # start local EVM at http://127.0.0.1:8545
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
* **Docs**: `hardhat-docgen` outputs Markdown docs to `packages/contracts/docs/` on compile.

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
EOF

# --- Git init (optional, resilient) ------------------------------------------------

if command -v git >/dev/null 2>&1; then
git init
git add -A
git -c user.name="bootstrap" -c user.email="bootstrap\@local" commit -m "chore: bootstrap web app and contracts workspace" || true
fi

echo
echo "Done. Next steps:"
echo "1) Edit apps/dao-dapp/.env.local  (set VITE\_WALLETCONNECT\_ID and RPC URLs)"
echo "2) Edit packages/contracts/.env.hardhat.local  (set deployer key, RPC URLs, explorer key)"
echo "3) If you see 'Ignored build scripts' warnings and want native speedups, run:"
echo "     pnpm approve-builds   # select: bufferutil, utf-8-validate, keccak, secp256k1"
echo "4) Compile contracts: pnpm contracts\:compile"
echo "5) Start web app:     pnpm web\:dev"