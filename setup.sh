#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup.sh — Rookie-proof DApp bootstrap (Hardhat **v2** lane)
# Frontend: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4
# Contracts: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6) + TypeChain
#            + hardhat-deploy + gas-reporter + contract-sizer + docgen + OpenZeppelin
# DX: Foundry (Forge/Anvil), ESLint/Prettier/Solhint, Husky + lint-staged, CI
# Notes:
# - Non-interactive Vite scaffold (no prompts)
# - Auto-stops any running `anvil` before Foundry updates
# - Places ABIs/artifacts into apps/dao-dapp/src/contracts for the frontend
# -----------------------------------------------------------------------------

# --- Helpers -----------------------------------------------------------------
info () { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok   () { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn () { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err  () { printf "\033[1;31m[x]\033[0m %s\n" "$*"; }

stop_anvil() {
  if pgrep -f '^anvil( |$)' >/dev/null 2>&1; then
    warn "Detected running anvil; stopping…"
    pkill -f '^anvil( |$)' || true
    sleep 1
    if pgrep -f '^anvil( |$)' >/dev/null 2>&1; then
      err "anvil still running; close it and re-run."
      exit 1
    fi
  fi
}

# --- Corepack & pnpm ---------------------------------------------------------
command -v corepack >/dev/null 2>&1 || { err "Corepack not found. Install Node.js >= 22 and retry."; exit 1; }
corepack enable
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack prepare pnpm@10.16.1 --activate
printf "v22\n" > .nvmrc
pnpm config set ignore-workspace-root-check true

# --- Root files --------------------------------------------------------------
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
    "contracts:verify": "pnpm --filter contracts exec hardhat etherscan-verify",

    "anvil:start": "anvil --block-time 1",
    "anvil:stop": "pkill -f '^anvil( |$)' || true",
    "foundry:update": "$HOME/.foundry/bin/foundryup",
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

# --- App scaffold (Vite + React + TS) ----------------------------------------
mkdir -p apps
if [ -d "apps/dao-dapp" ]; then
  info "apps/dao-dapp already exists; skipping scaffold."
else
  pnpm dlx create-vite@6 apps/dao-dapp --template react-ts --no-git --package-manager pnpm
fi

# Force React 18 (wagmi peer dep limit)
pnpm --dir apps/dao-dapp add react@18.3.1 react-dom@18.3.1
pnpm --dir apps/dao-dapp add -D @types/react@18.3.12 @types/react-dom@18.3.1

# Web3 + data
pnpm --dir apps/dao-dapp add @rainbow-me/rainbowkit@~2.2.8 wagmi@~2.16.9 viem@~2.37.6 @tanstack/react-query@~5.90.2
pnpm --dir apps/dao-dapp add @tanstack/react-query-devtools@~5.90.2 zod@~3.22.0

# Tailwind v4
pnpm --dir apps/dao-dapp add -D tailwindcss@~4.0.0 @tailwindcss/postcss@~4.0.0 postcss@~8.4.47
cat > apps/dao-dapp/postcss.config.mjs <<'EOF'
export default { plugins: { '@tailwindcss/postcss': {} } }
EOF
mkdir -p apps/dao-dapp/src
echo '@import "tailwindcss";' > apps/dao-dapp/src/index.css

# Artifacts dir for frontend
mkdir -p apps/dao-dapp/src/contracts
echo "# Generated contract artifacts" > apps/dao-dapp/src/contracts/.gitkeep

# Wagmi/RainbowKit config
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

# main.tsx
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

# Minimal App
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

# Env example
cat > apps/dao-dapp/.env.example <<'EOF'
VITE_WALLETCONNECT_ID=
VITE_MAINNET_RPC=https://cloudflare-eth.com
VITE_POLYGON_RPC=https://polygon-rpc.com
VITE_OPTIMISM_RPC=https://optimism.publicnode.com
VITE_ARBITRUM_RPC=https://arbitrum.publicnode.com
VITE_SEPOLIA_RPC=https://rpc.sepolia.org
EOF
cp -f apps/dao-dapp/.env.example apps/dao-dapp/.env.local

pnpm --dir apps/dao-dapp install

# --- Contracts workspace (Hardhat v2 + plugins) ------------------------------
mkdir -p packages/contracts

# contracts/package.json
cat > packages/contracts/package.json <<'EOF'
{
  "name": "contracts",
  "private": true,
  "scripts": {
    "clean": "hardhat clean",
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat deploy",
    "deploy:tags": "hardhat deploy --tags all",
    "etherscan-verify": "hardhat etherscan-verify"
  }
}
EOF

# tsconfig (CJS/Node16-style works smoothly with HH2 toolchain)
cat > packages/contracts/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "strict": true,
    "esModuleInterop": true,
    "moduleResolution": "Node16",
    "resolveJsonModule": true,
    "outDir": "dist",
    "types": ["node", "hardhat"]
  },
  "include": ["hardhat.config.ts", "deploy", "scripts", "test", "typechain-types"],
  "exclude": ["dist"]
}
EOF

# Hardhat v2 config (classic networks shape; toolbox + ethers v6; plugins)
cat > packages/contracts/hardhat.config.ts <<'EOF'
import { resolve } from 'node:path'
import { config as loadEnv } from 'dotenv'
import type { HardhatUserConfig } from 'hardhat/config'

import '@nomicfoundation/hardhat-toolbox'
import '@typechain/hardhat'
import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'hardhat-contract-sizer'
import 'hardhat-docgen'

loadEnv({ path: resolve(__dirname, '.env.hardhat.local') })

const privateKey = process.env.PRIVATE_KEY?.trim()
const mnemonic = process.env.MNEMONIC?.trim()
const accounts: any = privateKey ? [privateKey] : mnemonic ? { mnemonic } : undefined

const config: HardhatUserConfig = {
  solidity: { version: '0.8.28', settings: { optimizer: { enabled: true, runs: 200 } } },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    ...(process.env.SEPOLIA_RPC ? { sepolia: { url: process.env.SEPOLIA_RPC!, accounts } } : {}),
    ...(process.env.MAINNET_RPC ? { mainnet: { url: process.env.MAINNET_RPC!, accounts } } : {}),
    ...(process.env.POLYGON_RPC ? { polygon: { url: process.env.POLYGON_RPC!, accounts } } : {}),
    ...(process.env.OPTIMISM_RPC ? { optimism: { url: process.env.OPTIMISM_RPC!, accounts } } : {}),
    ...(process.env.ARBITRUM_RPC ? { arbitrum: { url: process.env.ARBITRUM_RPC!, accounts } } : {})
  },
  namedAccounts: { deployer: { default: 0 } },
  gasReporter: { enabled: true, currency: 'USD' },
  contractSizer: { runOnCompile: true },
  docgen: { outputDir: './docs', pages: 'items', collapseNewlines: true },
  paths: {
    sources: resolve(__dirname, 'contracts'),
    tests: resolve(__dirname, 'test'),
    cache: resolve(__dirname, 'cache'),
    artifacts: resolve(__dirname, '../../apps/dao-dapp/src/contracts')
  },
  etherscan: { apiKey: process.env.ETHERSCAN_API_KEY || '' }
}
export default config
EOF

# Dirs & example deploy
mkdir -p packages/contracts/contracts packages/contracts/deploy packages/contracts/scripts packages/contracts/test
echo "// Add your Solidity contracts here." > packages/contracts/contracts/.gitkeep

cat > packages/contracts/deploy/00_sample.ts <<'EOF'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  console.log('No contracts to deploy yet.')
  // await deploy('MyContract', { from: deployer, args: [], log: true })
}
export default func
func.tags = ['all']
EOF

cat > packages/contracts/scripts/deploy.ts <<'EOF'
async function main() {
  console.log('Use hardhat-deploy scripts in /deploy, or implement custom logic here.')
}
main().catch((e) => { console.error(e); process.exitCode = 1 })
EOF

echo "// Add your tests here" > packages/contracts/test/.gitkeep

# .env for contracts
cat > packages/contracts/.env.hardhat.example <<'EOF'
PRIVATE_KEY=
MNEMONIC=

MAINNET_RPC=
POLYGON_RPC=
OPTIMISM_RPC=
ARBITRUM_RPC=
SEPOLIA_RPC=

ETHERSCAN_API_KEY=
CMC_API_KEY=
EOF
cp -f packages/contracts/.env.hardhat.example packages/contracts/.env.hardhat.local

# --- Install contracts deps (HH2 lane) ---------------------------------------
pnpm --dir packages/contracts add -D \
  hardhat@^2.22.10 \
  @nomicfoundation/hardhat-toolbox@^4.0.0 \
  typescript@~5.9.2 ts-node@~10.9.2 @types/node@^22 dotenv@^16 \
  typechain @typechain/ethers-v6 @typechain/hardhat \
  hardhat-deploy hardhat-gas-reporter hardhat-contract-sizer hardhat-docgen

# Runtime deps
pnpm --dir packages/contracts add @openzeppelin/contracts @openzeppelin/contracts-upgradeable

# Install workspace lock
pnpm install

# --- Foundry (Forge/Anvil) ---------------------------------------------------
stop_anvil
if [ ! -x "$HOME/.foundry/bin/forge" ]; then
  info "Installing Foundry…"
  curl -L https://foundry.paradigm.xyz | bash
fi
"$HOME/.foundry/bin/foundryup" || warn "foundryup failed; rerun later with: pnpm foundry:update"

# foundry.toml + sample test
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
  function test_truth() public { assertTrue(true); }
}
EOF

# --- Lint/format & Husky -----------------------------------------------------
pnpm -w add -D eslint prettier husky lint-staged
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

pnpm dlx husky init
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

cat > .lintstagedrc.json <<'EOF'
{
  "*.{ts,tsx,js}": ["eslint --fix", "prettier --write"],
  "packages/contracts/**/*.sol": ["prettier --write", "solhint --fix"]
}
EOF

# --- CI ----------------------------------------------------------------------
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

# --- README ------------------------------------------------------------------
cat > README.md <<'EOF'
# DApp Setup (Rookie-friendly)

**Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4  
**Contracts**: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6), OpenZeppelin, TypeChain, hardhat-deploy  
**DX**: Foundry (Forge/Anvil), gas-reporter, contract-sizer, docgen, Solhint/Prettier, Husky  
**CI**: GitHub Actions

## 1) First-time setup
```bash
bash setup.sh
```

Fill envs:

* `apps/dao-dapp/.env.local`: `VITE_WALLETCONNECT_ID`, RPCs
* `packages/contracts/.env.hardhat.local`: `PRIVATE_KEY` or `MNEMONIC`, RPCs, `ETHERSCAN_API_KEY`, optional `CMC_API_KEY`

Optional speedups:

```bash
pnpm approve-builds
# select: bufferutil, utf-8-validate, keccak, secp256k1
```

## 2) Everyday commands

Frontend:

```bash
pnpm web:dev
```

Local chain:

```bash
pnpm anvil:start   # stop: pnpm anvil:stop
```

Contracts (Hardhat):

```bash
pnpm contracts:compile
pnpm contracts:test
pnpm contracts:deploy
pnpm contracts:verify
```

Contracts (Foundry):

```bash
pnpm forge:test
pnpm forge:fmt
pnpm foundry:update
```

## 3) Example contract (OpenZeppelin)

Create `packages/contracts/contracts/MyToken.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MyToken is ERC20 {
  constructor() ERC20("MyToken","MTK") { _mint(msg.sender, 1_000_000 ether); }
}
```

Deploy (create `packages/contracts/deploy/01_mytoken.ts`):

```ts
import type { DeployFunction } from 'hardhat-deploy/types'
const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments; const { deployer } = await getNamedAccounts();
  await deploy('MyToken', { from: deployer, args: [], log: true });
}
export default func; func.tags = ['MyToken'];
```

Run:

```bash
pnpm contracts:compile
pnpm --filter contracts exec hardhat deploy --network sepolia --tags MyToken
```

Artifacts (ABIs) appear in `apps/dao-dapp/src/contracts/`.

## 4) Docs (optional)

`hardhat-docgen` is enabled; docs will be generated into `packages/contracts/docs` on compile.
EOF

# --- Git init ----------------------------------------------------------------

if command -v git >/dev/null 2>&1; then
git init
git add -A
git -c user.name="bootstrap" -c user.email="bootstrap\@local" commit -m "chore: bootstrap DApp workspace (HH2 lane)" || true
fi

ok "Setup complete."
echo "Next:"
echo "1) Edit apps/dao-dapp/.env.local"
echo "2) Edit packages/contracts/.env.hardhat.local"
echo "3) pnpm contracts\:compile"
echo "4) pnpm web\:dev"