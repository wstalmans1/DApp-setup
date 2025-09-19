#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Bootstrap script to recreate a DApp-setup workspace in the CURRENT folder.
#
# How to use (from an EMPTY folder where you want to create the project):
# 1) Copy this file into that empty folder.
# 2) Open a terminal and cd into that folder.
# 3) Run one of the following:
#      bash DApp-setup.sh
#    OR
#      chmod +x DApp-setup.sh && ./DApp-setup.sh
# 4) After it finishes (no new subfolder is created):
#      pnpm contracts:compile
#      pnpm web:dev
#
# Required parameters (edit apps/dao-dapp/.env.local after script runs):
# - VITE_WALLETCONNECT_ID: Your WalletConnect Cloud Project ID
#     Get it at: https://cloud.walletconnect.com/
# - VITE_MAINNET_RPC: HTTPS RPC URL for Ethereum mainnet (no websockets)
#     Example: https://cloudflare-eth.com (public) or Infura/Alchemy HTTP URL
# - VITE_POLYGON_RPC: HTTPS RPC URL for Polygon
#     Example: https://polygon-rpc.com
# - VITE_OPTIMISM_RPC: HTTPS RPC URL for Optimism
#     Example: https://optimism.publicnode.com
# - VITE_ARBITRUM_RPC: HTTPS RPC URL for Arbitrum
#     Example: https://arbitrum.publicnode.com
# - VITE_SEPOLIA_RPC: HTTPS RPC URL for Sepolia testnet
#     Example: https://rpc.sepolia.org or your Infura/Alchemy HTTP URL
#
# Additional contract deployment parameters (edit packages/contracts/.env.hardhat.local):
# - PRIVATE_KEY or MNEMONIC: Credentials for contract deployment
# - MAINNET_RPC / POLYGON_RPC / OPTIMISM_RPC / ARBITRUM_RPC / SEPOLIA_RPC
# - ETHERSCAN / POLYGONSCAN / OPTIMISM_ETHERSCAN / ARBITRUM_ETHERSCAN API keys (optional, for verification)
#
# Notes:
# - Only HTTP endpoints are configured (no WebSockets) to avoid WS errors.
# - You can replace public endpoints with Infura/Alchemy URLs for reliability.
#
# Prerequisites:
# - Node.js 22 LTS recommended
# - Corepack available (the script checks and enables it)
# - Internet access
# -----------------------------------------------------------------------------

# Install in-place (.) — no subfolder creation.

# Node/pnpm setup
command -v corepack >/dev/null 2>&1 || {
  echo "Corepack not found. Please install Node.js >= 16.9 (Node 22 LTS recommended) and retry." >&2
  exit 1
}
corepack enable
# Avoid interactive Corepack prompts
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
# Prepare and activate the exact pnpm version for this shell
corepack prepare pnpm@10.16.1 --activate
printf "v22\n" > .nvmrc

# Root files
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
  "scripts": {
    "web:dev": "pnpm -C apps/dao-dapp dev",
    "web:build": "pnpm -C apps/dao-dapp build",
    "web:preview": "pnpm -C apps/dao-dapp preview",
    "contracts:compile": "pnpm -C packages/contracts hardhat compile",
    "contracts:test": "pnpm -C packages/contracts hardhat test",
    "contracts:deploy": "pnpm -C packages/contracts hardhat run scripts/deploy.ts",
    "contracts:verify": "pnpm -C packages/contracts hardhat verify"
  }
}
EOF

cat > pnpm-workspace.yaml <<'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF

# App scaffold (idempotent)
mkdir -p apps
if [ -d "apps/dao-dapp" ]; then
  echo "apps/dao-dapp already exists; skipping scaffold."
else
  pnpm create vite@latest apps/dao-dapp -- --template react-ts --no-git --package-manager pnpm
fi
pnpm -C apps/dao-dapp install

# App deps (web3 + styling)
pnpm -C apps/dao-dapp add wagmi viem @tanstack/react-query @rainbow-me/rainbowkit
pnpm -C apps/dao-dapp add -D tailwindcss @tailwindcss/postcss postcss

# Tailwind v4 (PostCSS plugin) config
cat > apps/dao-dapp/postcss.config.js <<'EOF'
export default { plugins: { '@tailwindcss/postcss': {} } };
EOF

# Tailwind entry (v4 style)
cat > apps/dao-dapp/src/index.css <<'EOF'
@import 'tailwindcss';
EOF

# Shared contracts artifacts folder for the web app
mkdir -p apps/dao-dapp/src/contracts
cat > apps/dao-dapp/src/contracts/.gitkeep <<'EOF'
# Generated contract artifacts are ignored by git but kept for tooling.
EOF

# Minimal RainbowKit/Wagmi config (HTTP only)
mkdir -p apps/dao-dapp/src/config
cat > apps/dao-dapp/src/config/wagmi.ts <<'EOF'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { mainnet, polygon, optimism, arbitrum, sepolia } from 'wagmi/chains'
import { http } from 'viem'

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

# main.tsx providers
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

const qc = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={qc}>
        <RainbowKitProvider>
          <App />
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
cp apps/dao-dapp/.env.example apps/dao-dapp/.env.local

# Contracts workspace (Hardhat + TypeScript)
mkdir -p packages/contracts
cat > packages/contracts/package.json <<'EOF'
{
  "name": "contracts",
  "private": true,
  "scripts": {
    "clean": "hardhat clean",
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.ts"
  }
}
EOF

cat > packages/contracts/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "es2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "outDir": "dist",
    "types": ["node", "hardhat"]
  },
  "include": ["hardhat.config.ts", "scripts", "test", "typechain-types"],
  "exclude": ["dist"]
}
EOF

cat > packages/contracts/hardhat.config.ts <<'EOF'
import { resolve } from 'path'
import { config as loadEnv } from 'dotenv'
import { HardhatUserConfig } from 'hardhat/config'
import { NetworkUserConfig } from 'hardhat/types'
import '@nomicfoundation/hardhat-toolbox'

loadEnv({ path: resolve(__dirname, '.env.hardhat.local') })

const privateKey = process.env.PRIVATE_KEY?.trim()
const mnemonic = process.env.MNEMONIC?.trim()

const accounts = (() => {
  if (privateKey) {
    return [privateKey]
  }
  if (mnemonic) {
    return { mnemonic }
  }
  return undefined
})()

const networks: Record<string, NetworkUserConfig> = {
  hardhat: {}
}

const addNetwork = (name: string, rpcUrl?: string) => {
  const url = rpcUrl?.trim()
  if (!url) return
  networks[name] = {
    url,
    ...(accounts ? { accounts } : {})
  }
}

addNetwork('mainnet', process.env.MAINNET_RPC)
addNetwork('polygon', process.env.POLYGON_RPC)
addNetwork('optimism', process.env.OPTIMISM_RPC)
addNetwork('arbitrumOne', process.env.ARBITRUM_RPC)
addNetwork('sepolia', process.env.SEPOLIA_RPC)

const etherscanApiKey: Record<string, string> = {}

if (process.env.ETHERSCAN_API_KEY?.trim()) {
  const key = process.env.ETHERSCAN_API_KEY.trim()
  etherscanApiKey.mainnet = key
  etherscanApiKey.sepolia = key
}
if (process.env.POLYGONSCAN_API_KEY?.trim()) {
  etherscanApiKey.polygon = process.env.POLYGONSCAN_API_KEY.trim()
}
if (process.env.OPTIMISM_ETHERSCAN_API_KEY?.trim()) {
  etherscanApiKey.optimisticEthereum = process.env.OPTIMISM_ETHERSCAN_API_KEY.trim()
}
if (process.env.ARBITRUM_ETHERSCAN_API_KEY?.trim()) {
  etherscanApiKey.arbitrumOne = process.env.ARBITRUM_ETHERSCAN_API_KEY.trim()
}

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: 'hardhat',
  networks,
  etherscan: {
    apiKey: etherscanApiKey
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

mkdir -p packages/contracts/contracts
cat > packages/contracts/contracts/.gitkeep <<'EOF'
# Add your Solidity contracts here.
EOF

mkdir -p packages/contracts/scripts
cat > packages/contracts/scripts/deploy.ts <<'EOF'
async function main() {
  console.log('Implement deployments in packages/contracts/scripts/deploy.ts before running this command.')
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

# Block explorer API keys
ETHERSCAN_API_KEY=
POLYGONSCAN_API_KEY=
OPTIMISM_ETHERSCAN_API_KEY=
ARBITRUM_ETHERSCAN_API_KEY=
EOF
cp packages/contracts/.env.hardhat.example packages/contracts/.env.hardhat.local

pnpm -C packages/contracts add -D hardhat @nomicfoundation/hardhat-toolbox typescript ts-node @types/node dotenv

# Git init (optional)
if command -v git >/dev/null 2>&1; then
  git init
  git add -A
  git commit -m "chore: bootstrap web app and contracts workspace"
fi

echo
echo "Done. Next steps:"
echo "1) Edit apps/dao-dapp/.env.local (set VITE_WALLETCONNECT_ID and RPC URLs)"
echo "2) Edit packages/contracts/.env.hardhat.local (set deployer key, RPC URLs, explorer keys)"
echo "3) pnpm contracts:compile"
echo "4) pnpm web:dev"
