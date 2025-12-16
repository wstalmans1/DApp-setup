#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup.sh — Rookie-proof DApp bootstrap (Hardhat **v2** lane)
# Frontend: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4
# State: Zustand v4 (global state) + Storacha account/space management store
# Contracts: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6) + TypeChain
#            + hardhat-deploy + gas-reporter + contract-sizer + docgen + OpenZeppelin
# DX: Foundry (Forge/Anvil), ESLint/Prettier/Solhint, Husky + lint-staged, Local Safety Net
# IPFS/IPNS: Helia v2 (full IPFS) + HTTP fallback + IPNS + @libp2p/crypto + @noble/curves + @storacha/client + @fleek-platform/sdk
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
.github/workflows
EOF

# Clean up any existing .github/workflows folder (we don't use GitHub Actions)
[ -d .github/workflows ] && rm -rf .github/workflows

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
    "contracts:verify:multi": "pnpm --filter contracts exec ts-node scripts/verify-multi.ts",
    "contracts:verify:stdjson": "pnpm --filter contracts exec ts-node scripts/verify-stdjson.ts",
    "contracts:docs": "pnpm --filter contracts run docs",
    "contracts:lint:natspec": "pnpm --filter contracts run lint:natspec",
    "contracts:debug": "pnpm --filter contracts exec ts-node scripts/debug-deployment.ts",
    "contracts:deploy-upgradeable": "pnpm --filter contracts exec ts-node scripts/deploy-upgradeable.ts",
    "contracts:upgrade": "pnpm --filter contracts exec ts-node scripts/upgrade-contract.ts",
    "contracts:verify-upgradeable": "pnpm --filter contracts exec ts-node scripts/verify-upgradeable.ts",

    "anvil:start": "anvil --block-time 1",
    "anvil:stop": "pkill -f '^anvil( |$)' || true",
    "foundry:update": "$HOME/.foundry/bin/foundryup",
    "forge:test": "forge test -vvv",
    "forge:fmt": "forge fmt",

    "check:all": "pnpm check:frontend && pnpm check:contracts",
    "check:frontend": "pnpm --dir apps/dao-dapp exec eslint . --ext .ts,.tsx && pnpm web:build",
    "check:contracts": "pnpm contracts:compile && pnpm contracts:test && pnpm forge:test",
    "check:quick": "pnpm --dir apps/dao-dapp exec eslint . --ext .ts,.tsx && pnpm --filter contracts exec solhint 'contracts/**/*.sol' || true",
    "check:full": "pnpm check:all"
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

# State management
pnpm --dir apps/dao-dapp add zustand@^4.5.0

# IPFS/IPNS - Helia (primary) + HTTP client (fallback) + IPNS support
# Core IPFS implementation (Helia)
pnpm --dir apps/dao-dapp add helia@^2.0.0 @helia/unixfs@^2.0.0 @helia/ipns@^2.0.0

# IPNS key generation and management
pnpm --dir apps/dao-dapp add @libp2p/crypto@^2.0.0

# Cryptography for wallet-based encryption
pnpm --dir apps/dao-dapp add @noble/curves@^1.0.0 @noble/hashes@^1.0.0

# CID handling for IPFS/IPNS
pnpm --dir apps/dao-dapp add multiformats@^13.0.0

# HTTP client fallback (for low-end devices, add later)
# Uncomment when implementing adaptive IPFS service:
# pnpm --dir apps/dao-dapp add ipfs-http-client@^60.0.0

# IPFS Pinning Services (choose one or multiple)
# Option 1: Storacha (official SDK for IPFS pinning and storage - email-based auth)
# Option 2: Pinata (official SDK for IPFS pinning and storage - v2.5.1 latest)
# Option 3: Fleek Platform SDK (official SDK for IPFS pinning and storage)
pnpm --dir apps/dao-dapp add @storacha/client@^1.0.0 pinata@^2.5.1 @fleek-platform/sdk@^3.0.0 axios@^1.7.0

# Tailwind v4
pnpm --dir apps/dao-dapp add -D tailwindcss@~4.0.0 @tailwindcss/postcss@~4.0.0 postcss@~8.4.47
cat > apps/dao-dapp/postcss.config.mjs <<'EOF'
export default { plugins: { '@tailwindcss/postcss': {} } }
EOF
mkdir -p apps/dao-dapp/src
cat > apps/dao-dapp/src/index.css <<'EOF'
@import "tailwindcss";

:root {
  color-scheme: dark;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  min-height: 100vh;
  font-family: "Inter", "SF Pro Text", system-ui, -apple-system, sans-serif;
  background: radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.08), transparent 30%),
    radial-gradient(circle at 80% 0%, rgba(99, 102, 241, 0.08), transparent 25%),
    #0b1221;
  color: #e5e7eb;
}

a {
  color: #93c5fd;
}
a:hover {
  color: #bfdbfe;
}
EOF

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
  appName: 'DAO DApp',
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
    <div className="relative min-h-screen overflow-hidden bg-slate-950 text-slate-100">
      <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/10 via-slate-950 to-indigo-500/10" aria-hidden />
      <div className="relative flex w-full flex-col gap-10 px-6 py-10">
        <header className="flex items-center justify-between rounded-2xl border border-white/5 bg-white/5 px-6 py-4 backdrop-blur">
          <div>
            <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Starter v27.2</p>
            <h1 className="text-2xl font-semibold text-white">DAO DApp</h1>
          </div>
          <ConnectButton />
        </header>
      </div>
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

# IPFS/IPNS Configuration
# Option 1: Storacha (Recommended for learning - free tier available)
# Email-based authentication: Users enter their email at runtime in the DApp
# Users must create account via CLI (storacha login) or console.storacha.network
# No environment variable needed - email is entered by user when logging in

# Option 2: Pinata (Recommended for production - free tier available)
# Get JWT from: https://app.pinata.cloud → API Keys → New Key
# Get Gateway from: https://app.pinata.cloud → Gateways (format: fun-llama-300.mypinata.cloud)
VITE_PINATA_JWT=
VITE_PINATA_GATEWAY=

# Local IPFS Node (Kubo) - Optional, for pinning to your own node
# Default: http://localhost:5001 (standard Kubo API port)
# Leave empty to disable local node pinning
VITE_LOCAL_IPFS_API=http://localhost:5001

# Option 3: Fleek Platform (IPFS pinning and storage service)
# Get CLIENT_ID from: https://app.fleek.co → Create Application → Get Client ID
VITE_FLEEK_CLIENT_ID=
VITE_FLEEK_GATEWAY=https://ipfs.fleek.co

# Option 4: Public IPFS Gateways (fallback)
VITE_IPFS_GATEWAY_1=https://dweb.link
VITE_IPFS_GATEWAY_2=https://ipfs.io
VITE_IPFS_GATEWAY_3=https://cloudflare-ipfs.com
VITE_IPFS_GATEWAY_4=https://gateway.pinata.cloud

# IPNS Configuration
VITE_IPNS_ENABLED=true
VITE_IPNS_REPUBLISH_INTERVAL=86400
EOF
cp -f apps/dao-dapp/.env.example apps/dao-dapp/.env.local

pnpm --dir apps/dao-dapp install

# Create IPFS/IPNS service directory structure
mkdir -p apps/dao-dapp/src/services/ipfs
mkdir -p apps/dao-dapp/src/services/ipns
mkdir -p apps/dao-dapp/src/services/encryption
mkdir -p apps/dao-dapp/src/types
mkdir -p apps/dao-dapp/src/utils
mkdir -p apps/dao-dapp/src/stores

# Create placeholder files for IPFS services
# Note: IPFS pinning service is implemented in:
# - apps/dao-dapp/src/services/ipfs/pinning.ts (Pinata, local node, Helia pinning)
# - apps/dao-dapp/src/services/ipfs.ts (Main IPFS service with auto-pinning)
# These files are created during Phase 1 of the learning path, not by setup.sh
cat > apps/dao-dapp/src/services/ipfs/.gitkeep <<'EOF'
# IPFS service implementation
# Supports multiple pinning providers:
# - Storacha (via @storacha/client)
#   Email-based authentication: Users enter email at runtime, use client.login(email) in code
#   Requires account setup via CLI (storacha login) or console.storacha.network
# - Pinata (via pinata SDK v2.5.1 - VITE_PINATA_JWT, VITE_PINATA_GATEWAY)
#   Usage: pinata.upload.public.cid(cid) for pinning existing CIDs
#   Usage: pinata.files.public.list().cid(cid) for checking pin status
# - Fleek Platform (via @fleek-platform/sdk/browser - VITE_FLEEK_CLIENT_ID)
#   Uses ApplicationAccessTokenService for client-side authentication
# Users can configure which provider(s) to use via environment variables
EOF

cat > apps/dao-dapp/src/services/ipfs/providers.ts <<'EOF'
// IPFS provider configuration and selection
// Supports multiple pinning providers:
// - Storacha (via @storacha/client)
//   Usage: import { create } from "@storacha/client"
//   const client = await create()
//   const account = await client.login(email) // Email entered by user at runtime
//   await account.plan.wait() // Wait for payment plan selection
//   const space = await client.createSpace("my-space", { account })
//   const cid = await client.uploadFile(file)
// - Pinata (via pinata SDK v2.5.1 - VITE_PINATA_JWT, VITE_PINATA_GATEWAY)
//   Usage: import { PinataSDK } from "pinata"
//   const pinata = new PinataSDK({ pinataJwt, pinataGateway })
//   Pin existing CID: await pinata.upload.public.cid(cid)
//   Check pin status: await pinata.files.public.list().cid(cid)
// - Fleek Platform (via @fleek-platform/sdk/browser - VITE_FLEEK_CLIENT_ID)
//   Uses ApplicationAccessTokenService for client-side authentication
// Users can configure which provider(s) to use via environment variables
// Will be implemented in learning path
EOF

cat > apps/dao-dapp/src/services/ipns/.gitkeep <<'EOF'
# IPNS service implementation
EOF

cat > apps/dao-dapp/src/services/encryption/.gitkeep <<'EOF'
# Encryption service implementation
EOF

# Create example component showing Zustand store usage
mkdir -p apps/dao-dapp/src/components
cat > apps/dao-dapp/src/components/StorachaManager.tsx <<'EOF'
import { useState } from 'react'
import { useStorachaStore } from '../stores'

/**
 * Example component demonstrating Zustand store usage for Storacha account and space management
 * This is a scaffold - implement actual Storacha SDK integration in your learning path
 */
export default function StorachaManager() {
  const {
    // State
    currentAccount,
    isAuthenticated,
    accounts,
    spaces,
    selectedSpace,
    spaceContents,
    isLoading,
    isLoadingSpaces,
    isLoadingContents,
    error,
    // Actions
    login,
    logout,
    switchAccount,
    addAccount,
    removeAccount,
    fetchSpaces,
    createSpace,
    deleteSpace,
    selectSpace,
    uploadToSpace,
    deleteFromSpace,
    clearError,
  } = useStorachaStore()

  const [email, setEmail] = useState('')
  const [newSpaceName, setNewSpaceName] = useState('')

  const handleLogin = async () => {
    if (!email) return
    try {
      await login(email)
      await fetchSpaces()
    } catch (err) {
      console.error('Login failed:', err)
    }
  }

  const handleLogout = () => {
    logout()
    setEmail('')
  }

  const handleSwitchAccount = async (accountId: string) => {
    await switchAccount(accountId)
  }

  const handleCreateSpace = async () => {
    if (!newSpaceName) return
    try {
      await createSpace(newSpaceName)
      setNewSpaceName('')
    } catch (err) {
      console.error('Failed to create space:', err)
    }
  }

  const handleDeleteSpace = async (spaceId: string) => {
    if (!confirm('Are you sure you want to delete this space?')) return
    try {
      await deleteSpace(spaceId)
    } catch (err) {
      console.error('Failed to delete space:', err)
    }
  }

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !selectedSpace) return
    try {
      await uploadToSpace(selectedSpace.id, file)
    } catch (err) {
      console.error('Failed to upload file:', err)
    }
  }

  const handleDeleteContent = async (contentId: string) => {
    if (!selectedSpace) return
    if (!confirm('Are you sure you want to delete this content?')) return
    try {
      await deleteFromSpace(selectedSpace.id, contentId)
    } catch (err) {
      console.error('Failed to delete content:', err)
    }
  }

  return (
    <div className="rounded-2xl border border-white/5 bg-white/5 p-6 backdrop-blur">
      <h2 className="text-xl font-semibold mb-4">Storacha Account Manager</h2>

      {error && (
        <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg">
          <p className="text-red-400 text-sm">{error}</p>
          <button
            onClick={clearError}
            className="mt-2 text-xs text-red-400 hover:text-red-300"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Authentication Section */}
      <div className="mb-6">
        <h3 className="text-lg font-medium mb-3">Authentication</h3>
        {!isAuthenticated ? (
          <div className="space-y-2">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your Storacha email"
              className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-slate-400"
            />
            <button
              onClick={handleLogin}
              disabled={isLoading || !email}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 rounded-lg"
            >
              {isLoading ? 'Logging in...' : 'Login'}
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            <p className="text-sm text-slate-400">
              Logged in as: <span className="text-white">{currentAccount?.email}</span>
            </p>
            <button
              onClick={handleLogout}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg"
            >
              Logout
            </button>
          </div>
        )}
      </div>

      {/* Multiple Accounts Section */}
      {accounts.length > 1 && (
        <div className="mb-6">
          <h3 className="text-lg font-medium mb-3">Switch Account</h3>
          <div className="space-y-2">
            {accounts.map((account) => (
              <button
                key={account.id}
                onClick={() => handleSwitchAccount(account.id)}
                className={`w-full px-3 py-2 text-left rounded-lg border ${
                  currentAccount?.id === account.id
                    ? 'border-blue-500 bg-blue-500/10'
                    : 'border-white/10 bg-white/5 hover:bg-white/10'
                }`}
              >
                {account.email}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Spaces Section */}
      {isAuthenticated && (
        <div className="mb-6">
          <h3 className="text-lg font-medium mb-3">Spaces</h3>
          <div className="space-y-2 mb-3">
            <input
              type="text"
              value={newSpaceName}
              onChange={(e) => setNewSpaceName(e.target.value)}
              placeholder="New space name"
              className="w-full px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-slate-400"
            />
            <button
              onClick={handleCreateSpace}
              disabled={isLoadingSpaces || !newSpaceName}
              className="px-4 py-2 bg-green-600 hover:bg-green-700 disabled:opacity-50 rounded-lg"
            >
              Create Space
            </button>
          </div>
          {isLoadingSpaces ? (
            <p className="text-slate-400 text-sm">Loading spaces...</p>
          ) : spaces.length === 0 ? (
            <p className="text-slate-400 text-sm">No spaces yet. Create one above!</p>
          ) : (
            <div className="space-y-2">
              {spaces.map((space) => (
                <div
                  key={space.id}
                  className={`p-3 rounded-lg border ${
                    selectedSpace?.id === space.id
                      ? 'border-blue-500 bg-blue-500/10'
                      : 'border-white/10 bg-white/5 hover:bg-white/10'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <button
                      onClick={() => selectSpace(space)}
                      className="flex-1 text-left"
                    >
                      <p className="font-medium">{space.name}</p>
                    </button>
                    <button
                      onClick={() => handleDeleteSpace(space.id)}
                      className="ml-2 px-2 py-1 text-xs bg-red-600 hover:bg-red-700 rounded"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Space Contents Section */}
      {isAuthenticated && selectedSpace && (
        <div>
          <h3 className="text-lg font-medium mb-3">
            Contents: {selectedSpace.name}
          </h3>
          <div className="mb-3">
            <input
              type="file"
              onChange={handleFileUpload}
              disabled={isLoadingContents}
              className="text-sm text-slate-400"
            />
          </div>
          {isLoadingContents ? (
            <p className="text-slate-400 text-sm">Loading contents...</p>
          ) : (
            <div className="space-y-2">
              {spaceContents[selectedSpace.id]?.length === 0 ? (
                <p className="text-slate-400 text-sm">No contents yet. Upload a file above!</p>
              ) : (
                spaceContents[selectedSpace.id]?.map((content) => (
                  <div
                    key={content.id}
                    className="p-3 rounded-lg border border-white/10 bg-white/5 flex items-center justify-between"
                  >
                    <div>
                      <p className="font-medium">{content.name}</p>
                      {content.size && (
                        <p className="text-xs text-slate-400">
                          {(content.size / 1024).toFixed(2)} KB
                        </p>
                      )}
                    </div>
                    <button
                      onClick={() => handleDeleteContent(content.id)}
                      className="ml-2 px-2 py-1 text-xs bg-red-600 hover:bg-red-700 rounded"
                    >
                      Delete
                    </button>
                  </div>
                ))
              )}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
EOF

# Create IPFS test component scaffold (for Phase 1 testing)
# This is a basic scaffold - full implementation is created during Phase 1
cat > apps/dao-dapp/src/components/IPFSTest.tsx <<'EOF'
import { useState, useEffect } from 'react'
// IPFS service imports will be added during Phase 1 implementation
// import { uploadToIPFS, getFromIPFS, stopHelia, pinCID } from '../services/ipfs'
// import { checkPinningStatus } from '../services/ipfs/pinning'
// import { getHelia } from '../services/ipfs'

export default function IPFSTest() {
  const [initializing, setInitializing] = useState(true)

  useEffect(() => {
    // IPFS initialization will be implemented during Phase 1
    setInitializing(false)
  }, [])

  if (initializing) {
    return (
      <div className="rounded-2xl border border-white/5 bg-white/5 p-6 backdrop-blur">
        <h2 className="text-xl font-semibold mb-4">IPFS Test</h2>
        <p className="text-slate-400">Initializing IPFS node...</p>
      </div>
    )
  }

  return (
    <div className="rounded-2xl border border-white/5 bg-white/5 p-6 backdrop-blur">
      <h2 className="text-xl font-semibold mb-4">IPFS Test (Helia)</h2>
      <p className="text-slate-400 text-sm">
        IPFS test component - will be fully implemented during Phase 1 of the learning path.
        See: Docs/IPFS_IPNS learning/QUICKSTART_PHASE1.md
      </p>
    </div>
  )
}
EOF

cat > apps/dao-dapp/src/types/profile.ts <<'EOF'
// Profile type definitions
// Will be implemented in learning path Phase 4
EOF

# Storacha types
cat > apps/dao-dapp/src/types/storacha.ts <<'EOF'
// Storacha account and space type definitions
// These types match the @storacha/client SDK structure

export interface StorachaAccount {
  id: string
  email: string
  // Add other account properties as needed based on @storacha/client SDK
}

export interface StorachaSpace {
  id: string
  name: string
  // Add other space properties as needed based on @storacha/client SDK
}

export interface StorachaContent {
  id: string
  name: string
  cid?: string
  size?: number
  type?: string
  // Add other content properties as needed based on @storacha/client SDK
}
EOF

# Zustand store for Storacha account and space management
cat > apps/dao-dapp/src/stores/useStorachaStore.ts <<'EOF'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { StorachaAccount, StorachaSpace, StorachaContent } from '../types/storacha'

interface StorachaStore {
  // Authentication state
  currentAccount: StorachaAccount | null
  isAuthenticated: boolean
  accounts: StorachaAccount[] // Multiple accounts user can switch between
  isLoading: boolean
  error: string | null

  // Spaces state
  spaces: StorachaSpace[]
  selectedSpace: StorachaSpace | null
  isLoadingSpaces: boolean

  // Space contents state
  spaceContents: Record<string, StorachaContent[]> // spaceId -> contents
  isLoadingContents: boolean

  // Authentication actions
  login: (email: string) => Promise<void>
  logout: () => void
  switchAccount: (accountId: string) => Promise<void>
  addAccount: (account: StorachaAccount) => void
  removeAccount: (accountId: string) => void

  // Spaces actions
  fetchSpaces: () => Promise<void>
  createSpace: (name: string) => Promise<void>
  deleteSpace: (spaceId: string) => Promise<void>
  selectSpace: (space: StorachaSpace | null) => void

  // Space contents actions
  fetchSpaceContents: (spaceId: string) => Promise<void>
  uploadToSpace: (spaceId: string, file: File) => Promise<void>
  deleteFromSpace: (spaceId: string, contentId: string) => Promise<void>

  // Utility actions
  clearError: () => void
  reset: () => void
}

const initialState = {
  currentAccount: null,
  isAuthenticated: false,
  accounts: [],
  isLoading: false,
  error: null,
  spaces: [],
  selectedSpace: null,
  isLoadingSpaces: false,
  spaceContents: {},
  isLoadingContents: false,
}

export const useStorachaStore = create<StorachaStore>()(
  persist(
    (set, get) => ({
      ...initialState,

      // Authentication actions
      login: async (email: string) => {
        set({ isLoading: true, error: null })
        try {
          // TODO: Implement actual Storacha login
          // import { create } from '@storacha/client'
          // const client = await create()
          // const account = await client.login(email)
          
          // For now, create a mock account
          const account: StorachaAccount = {
            id: `account-${Date.now()}`,
            email,
          }

          set((state) => ({
            currentAccount: account,
            isAuthenticated: true,
            accounts: state.accounts.some((a) => a.id === account.id)
              ? state.accounts
              : [...state.accounts, account],
            isLoading: false,
            error: null,
          }))
        } catch (error) {
          set({
            isLoading: false,
            error: error instanceof Error ? error.message : 'Login failed',
          })
          throw error
        }
      },

      logout: () => {
        set({
          currentAccount: null,
          isAuthenticated: false,
          selectedSpace: null,
          spaces: [],
          spaceContents: {},
        })
      },

      switchAccount: async (accountId: string) => {
        const account = get().accounts.find((a) => a.id === accountId)
        if (!account) {
          set({ error: 'Account not found' })
          return
        }

        set({
          currentAccount: account,
          isAuthenticated: true,
          selectedSpace: null,
          spaces: [],
          spaceContents: {},
        })

        // Automatically fetch spaces for the new account
        await get().fetchSpaces()
      },

      addAccount: (account: StorachaAccount) => {
        set((state) => ({
          accounts: state.accounts.some((a) => a.id === account.id)
            ? state.accounts
            : [...state.accounts, account],
        }))
      },

      removeAccount: (accountId: string) => {
        set((state) => {
          const newAccounts = state.accounts.filter((a) => a.id !== accountId)
          const isCurrentAccount = state.currentAccount?.id === accountId
          return {
            accounts: newAccounts,
            currentAccount: isCurrentAccount ? null : state.currentAccount,
            isAuthenticated: isCurrentAccount ? false : state.isAuthenticated,
            selectedSpace: isCurrentAccount ? null : state.selectedSpace,
            spaces: isCurrentAccount ? [] : state.spaces,
            spaceContents: isCurrentAccount ? {} : state.spaceContents,
          }
        })
      },

      // Spaces actions
      fetchSpaces: async () => {
        const { currentAccount } = get()
        if (!currentAccount) {
          set({ error: 'No account selected' })
          return
        }

        set({ isLoadingSpaces: true, error: null })
        try {
          // TODO: Implement actual Storacha spaces fetching
          // const client = await create()
          // const account = await client.login(currentAccount.email)
          // const spaces = await account.listSpaces()
          
          // For now, return empty array
          const spaces: StorachaSpace[] = []

          set({ spaces, isLoadingSpaces: false })
        } catch (error) {
          set({
            isLoadingSpaces: false,
            error: error instanceof Error ? error.message : 'Failed to fetch spaces',
          })
        }
      },

      createSpace: async (name: string) => {
        const { currentAccount } = get()
        if (!currentAccount) {
          set({ error: 'No account selected' })
          return
        }

        set({ isLoadingSpaces: true, error: null })
        try {
          // TODO: Implement actual Storacha space creation
          // const client = await create()
          // const account = await client.login(currentAccount.email)
          // const space = await client.createSpace(name, { account })
          
          // For now, create a mock space
          const newSpace: StorachaSpace = {
            id: `space-${Date.now()}`,
            name,
          }

          set((state) => ({
            spaces: [...state.spaces, newSpace],
            isLoadingSpaces: false,
          }))
        } catch (error) {
          set({
            isLoadingSpaces: false,
            error: error instanceof Error ? error.message : 'Failed to create space',
          })
          throw error
        }
      },

      deleteSpace: async (spaceId: string) => {
        set({ isLoadingSpaces: true, error: null })
        try {
          // TODO: Implement actual Storacha space deletion
          // const client = await create()
          // const account = await client.login(get().currentAccount!.email)
          // await account.deleteSpace(spaceId)

          set((state) => {
            const newSpaces = state.spaces.filter((s) => s.id !== spaceId)
            const newContents = { ...state.spaceContents }
            delete newContents[spaceId]
            return {
              spaces: newSpaces,
              selectedSpace: state.selectedSpace?.id === spaceId ? null : state.selectedSpace,
              spaceContents: newContents,
              isLoadingSpaces: false,
            }
          })
        } catch (error) {
          set({
            isLoadingSpaces: false,
            error: error instanceof Error ? error.message : 'Failed to delete space',
          })
          throw error
        }
      },

      selectSpace: (space: StorachaSpace | null) => {
        set({ selectedSpace: space })
        if (space) {
          // Automatically fetch contents when space is selected
          get().fetchSpaceContents(space.id)
        }
      },

      // Space contents actions
      fetchSpaceContents: async (spaceId: string) => {
        set({ isLoadingContents: true, error: null })
        try {
          // TODO: Implement actual Storacha contents fetching
          // const client = await create()
          // const account = await client.login(get().currentAccount!.email)
          // const contents = await account.listSpaceContents(spaceId)
          
          // For now, return empty array
          const contents: StorachaContent[] = []

          set((state) => ({
            spaceContents: {
              ...state.spaceContents,
              [spaceId]: contents,
            },
            isLoadingContents: false,
          }))
        } catch (error) {
          set({
            isLoadingContents: false,
            error: error instanceof Error ? error.message : 'Failed to fetch space contents',
          })
        }
      },

      uploadToSpace: async (spaceId: string, file: File) => {
        set({ isLoadingContents: true, error: null })
        try {
          // TODO: Implement actual Storacha file upload
          // const client = await create()
          // const account = await client.login(get().currentAccount!.email)
          // const cid = await client.uploadFile(file, { spaceId })
          
          // For now, create a mock content
          const newContent: StorachaContent = {
            id: `content-${Date.now()}`,
            name: file.name,
            size: file.size,
            type: file.type,
          }

          set((state) => ({
            spaceContents: {
              ...state.spaceContents,
              [spaceId]: [...(state.spaceContents[spaceId] || []), newContent],
            },
            isLoadingContents: false,
          }))
        } catch (error) {
          set({
            isLoadingContents: false,
            error: error instanceof Error ? error.message : 'Failed to upload file',
          })
          throw error
        }
      },

      deleteFromSpace: async (spaceId: string, contentId: string) => {
        set({ isLoadingContents: true, error: null })
        try {
          // TODO: Implement actual Storacha content deletion
          // const client = await create()
          // const account = await client.login(get().currentAccount!.email)
          // await account.deleteContent(spaceId, contentId)

          set((state) => ({
            spaceContents: {
              ...state.spaceContents,
              [spaceId]: (state.spaceContents[spaceId] || []).filter(
                (c) => c.id !== contentId
              ),
            },
            isLoadingContents: false,
          }))
        } catch (error) {
          set({
            isLoadingContents: false,
            error: error instanceof Error ? error.message : 'Failed to delete content',
          })
          throw error
        }
      },

      // Utility actions
      clearError: () => {
        set({ error: null })
      },

      reset: () => {
        set(initialState)
      },
    }),
    {
      name: 'storacha-storage', // localStorage key
      partialize: (state) => ({
        // Only persist authentication state, not loading/error states
        currentAccount: state.currentAccount,
        isAuthenticated: state.isAuthenticated,
        accounts: state.accounts,
        selectedSpace: state.selectedSpace,
      }),
    }
  )
)
EOF

# Store index file
cat > apps/dao-dapp/src/stores/index.ts <<'EOF'
// Export all stores from a single entry point
export { useStorachaStore } from './useStorachaStore'
EOF

cat > apps/dao-dapp/src/utils/deviceCapabilities.ts <<'EOF'
// Device capability detection
// Will be implemented when adding adaptive IPFS service
EOF

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
    "etherscan-verify": "hardhat etherscan-verify",
    "docs": "hardhat docgen",
    "lint:natspec": "solhint 'contracts/**/*.sol' --config .solhint.json"
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
import { promises as fs } from 'node:fs'
import { config as loadEnv } from 'dotenv'
import { task, type HardhatUserConfig } from 'hardhat/config'
import type { BuildInfo, HardhatRuntimeEnvironment } from 'hardhat/types'
import { docgen as runDocgen } from 'solidity-docgen'

import '@nomicfoundation/hardhat-toolbox'
import '@typechain/hardhat'
import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'hardhat-contract-sizer'
import '@openzeppelin/hardhat-upgrades'

loadEnv({ path: resolve(__dirname, '.env.hardhat.local') })

const privateKey = process.env.PRIVATE_KEY?.trim()
const mnemonic = process.env.MNEMONIC?.trim()
const accounts: any = privateKey ? [privateKey] : mnemonic ? { mnemonic } : undefined
// Auto doc generation runs post-compile unless DOCS_AUTOGEN=false is set
const docsAutogenEnv = process.env.DOCS_AUTOGEN?.toLowerCase()
const shouldAutoGenerateDocs = docsAutogenEnv !== 'false'

// Reuse the most recent Solc build outputs to generate Markdown docs without recompiling
async function generateDocs(hre: HardhatRuntimeEnvironment) {
  const buildInfoPaths = await hre.artifacts.getBuildInfoPaths()
  if (buildInfoPaths.length === 0) return

  const builds = await Promise.all(
    buildInfoPaths.map(async buildInfoPath => {
      const contents = await fs.readFile(buildInfoPath, 'utf8')
      const buildInfo = JSON.parse(contents) as BuildInfo
      return { input: buildInfo.input, output: buildInfo.output }
    })
  )

  await runDocgen(builds, hre.config.docgen)
}

task('compile').setAction(async (args, hre, runSuper) => {
  const result = await runSuper(args)
  if (shouldAutoGenerateDocs) await generateDocs(hre)
  return result
})

const config: HardhatUserConfig = {
  solidity: { 
    version: '0.8.28', 
    settings: { 
      optimizer: { enabled: true, runs: 200 },
      outputSelection: {
        '*': {
          '*': ['*', 'evm.bytecode.object', 'evm.deployedBytecode.object', 'metadata']
        }
      }
    } 
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    ...(process.env.SEPOLIA_RPC ? { sepolia: { url: process.env.SEPOLIA_RPC!, accounts } } : {}),
    // Optional alias network to use Blockscout endpoints for verification while reusing Sepolia RPC
    ...(process.env.SEPOLIA_RPC ? { 'sepolia-blockscout': { url: process.env.SEPOLIA_RPC!, accounts } } : {}),
    ...(process.env.MAINNET_RPC ? { mainnet: { url: process.env.MAINNET_RPC!, accounts } } : {}),
    ...(process.env.POLYGON_RPC ? { polygon: { url: process.env.POLYGON_RPC!, accounts } } : {}),
    ...(process.env.OPTIMISM_RPC ? { optimism: { url: process.env.OPTIMISM_RPC!, accounts } } : {}),
    ...(process.env.ARBITRUM_RPC ? { arbitrum: { url: process.env.ARBITRUM_RPC!, accounts } } : {})
  },
  namedAccounts: { deployer: { default: 0 } },
  gasReporter: { enabled: true, currency: 'USD' },
  contractSizer: { runOnCompile: true },
  docgen: {
    outputDir: 'docs',
    pages: 'files',
    theme: 'markdown',
    collapseNewlines: true
  },
  paths: {
    sources: resolve(__dirname, 'contracts'),
    tests: resolve(__dirname, 'test'),
    cache: resolve(__dirname, 'cache'),
    artifacts: resolve(__dirname, '../../apps/dao-dapp/src/contracts')
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      // Blockscout generally ignores API keys; a placeholder keeps plugin happy
      'sepolia-blockscout': 'dummy'
    },
    customChains: [
      {
        network: 'sepolia-blockscout',
        chainId: 11155111,
        urls: {
          apiURL: 'https://eth-sepolia.blockscout.com/api',
          browserURL: 'https://eth-sepolia.blockscout.com'
        }
      }
    ]
  }
}
export default config
EOF

# Dirs & example deploy
mkdir -p packages/contracts/contracts packages/contracts/deploy packages/contracts/scripts packages/contracts/test
# Create example contract with comprehensive NatSpec documentation
cat > packages/contracts/contracts/ExampleToken.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ExampleToken
 * @author Your Name
 * @notice This is an example ERC20 token contract with comprehensive NatSpec documentation
 * @dev This contract demonstrates proper NatSpec usage for documentation generation
 * @custom:security-contact security@example.com
 */
contract ExampleToken is ERC20, Ownable {
    /// @notice Maximum supply of tokens that can ever be minted
    /// @dev Set to 1 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    /// @notice Address of the treasury where fees are collected
    /// @dev Can be updated by the owner
    address public treasury;

    /// @notice Emitted when the treasury address is updated
    /// @param oldTreasury The previous treasury address
    /// @param newTreasury The new treasury address
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when tokens are minted
    /// @param to The address that received the tokens
    /// @param amount The amount of tokens minted
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @notice Constructs the ExampleToken contract
     * @dev Initializes the ERC20 token with name "Example Token" and symbol "EXT"
     * @param initialOwner The address that will be set as the initial owner
     * @param initialTreasury The initial treasury address for fee collection
     */
    constructor(address initialOwner, address initialTreasury) ERC20("Example Token", "EXT") Ownable(initialOwner) {
        require(initialTreasury != address(0), "ExampleToken: treasury cannot be zero address");
        treasury = initialTreasury;
    }

    /**
     * @notice Mints tokens to a specified address
     * @dev Only the owner can mint tokens, and the total supply cannot exceed MAX_SUPPLY
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     * @return success True if the minting was successful
     */
    function mint(address to, uint256 amount) external onlyOwner returns (bool success) {
        require(to != address(0), "ExampleToken: cannot mint to zero address");
        require(totalSupply() + amount <= MAX_SUPPLY, "ExampleToken: would exceed max supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
        return true;
    }

    /**
     * @notice Updates the treasury address
     * @dev Only the owner can update the treasury address
     * @param newTreasury The new treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "ExampleToken: treasury cannot be zero address");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Returns the current treasury address
     * @dev This is a view function that doesn't modify state
     * @return The current treasury address
     */
    function getTreasury() external view returns (address) {
        return treasury;
    }

    /**
     * @notice Returns the maximum supply of tokens
     * @dev This is a view function that returns the constant MAX_SUPPLY
     * @return The maximum supply of tokens
     */
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }
}
EOF

cat > packages/contracts/deploy/00_example_token.ts <<'EOF'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  
  // Deploy ExampleToken with comprehensive NatSpec documentation
  await deploy('ExampleToken', {
    from: deployer,
    args: [deployer, deployer], // initialOwner and initialTreasury both set to deployer
    log: true,
  })
}
export default func
func.tags = ['ExampleToken', 'all']
EOF

cat > packages/contracts/scripts/deploy.ts <<'EOF'
async function main() {
  console.log('Use hardhat-deploy scripts in /deploy, or implement custom logic here.')
}
main().catch((e) => { console.error(e); process.exitCode = 1 })
EOF

# Debug a deployed address (basic utilities)
cat > packages/contracts/scripts/debug-deployment.ts <<'EOF'
import { ethers } from "hardhat"

async function main() {
  const address = process.argv[2]
  if (!address) throw new Error("Usage: ts-node scripts/debug-deployment.ts <address>")

  const code = await ethers.provider.getCode(address)
  const balance = await ethers.provider.getBalance(address)
  console.log("Code size:", (code.length - 2) / 2, "bytes")
  console.log("ETH balance:", ethers.formatEther(balance))
}

main().catch((e) => { console.error(e); process.exit(1) })
EOF

# Deploy an upgradeable proxy for UpgradeableToken (example)
cat > packages/contracts/scripts/deploy-upgradeable.ts <<'EOF'
import { ethers, upgrades } from "hardhat"

async function main() {
  const [owner] = await ethers.getSigners()
  const treasury = owner.address

  const Impl = await ethers.getContractFactory("UpgradeableToken")
  const proxy = await upgrades.deployProxy(Impl, [owner.address, treasury])
  await proxy.waitForDeployment()
  console.log("Proxy deployed:", await proxy.getAddress())
}

main().catch((e) => { console.error(e); process.exit(1) })
EOF

# Upgrade an existing proxy to a new implementation
cat > packages/contracts/scripts/upgrade-contract.ts <<'EOF'
import { ethers, upgrades } from "hardhat"

async function main() {
  const proxyAddress = process.argv[2]
  const newImplName = process.argv[3] || "UpgradeableTokenV2"
  if (!proxyAddress) throw new Error("Usage: ts-node scripts/upgrade-contract.ts <proxyAddress> [ImplName]")

  const NewImpl = await ethers.getContractFactory(newImplName)
  const upgraded = await upgrades.upgradeProxy(proxyAddress, NewImpl)
  console.log("Upgraded proxy at:", await upgraded.getAddress())
}

main().catch((e) => { console.error(e); process.exit(1) })
EOF

# Verify an upgradeable proxy + implementation on explorer
cat > packages/contracts/scripts/verify-upgradeable.ts <<'EOF'
import hre from "hardhat"

async function main() {
  const proxyAddress = process.argv[2]
  if (!proxyAddress) throw new Error("Usage: ts-node scripts/verify-upgradeable.ts <proxyAddress>")

  try {
    await hre.run("verify:verify", { address: proxyAddress })
    console.log("✅ Verified proxy address")
  } catch (e: any) {
    console.log("❌ Proxy verification failed:", e.message || e)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
EOF

# Multi-explorer verification scripts
cat > packages/contracts/scripts/verify-multi.ts <<'EOF'
import hre from "hardhat"

async function main() {
  const address = process.argv[2]
  if (!address) throw new Error("Usage: ts-node scripts/verify-multi.ts <address> [constructorArgsJson]")

  const argsJson = process.argv[3]
  const constructorArgs: any[] = argsJson ? JSON.parse(argsJson) : []

  console.log("Verifying on Etherscan…")
  try {
    await hre.run("verify:verify", { address, constructorArguments: constructorArgs })
    console.log("✅ Etherscan verified")
    return
  } catch (e: any) {
    console.log("❌ Etherscan failed:", e.message || e)
  }

  console.log("Verifying on Blockscout…")
  try {
    await hre.run("verify:verify", { address, network: "sepolia-blockscout", constructorArguments: constructorArgs })
    console.log("✅ Blockscout verified")
  } catch (e: any) {
    console.log("❌ Blockscout failed:", e.message || e)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
EOF

cat > packages/contracts/scripts/verify-stdjson.ts <<'EOF'
import hre from "hardhat"
import fs from "fs"

async function main() {
  const address = process.argv[2]
  const stdJsonPath = process.argv[3]
  const contractFullyQualifiedName = process.argv[4] // e.g. contracts/My.sol:My
  if (!address || !stdJsonPath || !contractFullyQualifiedName) {
    throw new Error("Usage: ts-node scripts/verify-stdjson.ts <address> <standardJsonPath> <FQN>")
  }

  const standardJsonInput = fs.readFileSync(stdJsonPath, "utf8")

  // First try Etherscan (supports standard-json-input)
  try {
    await hre.run("verify:verify", {
      address,
      contract: contractFullyQualifiedName,
      constructorArguments: [],
      libraries: {},
      standardJsonInput,
    })
    console.log("✅ Etherscan verified via standard JSON input")
    return
  } catch (e: any) {
    console.log("❌ Etherscan failed:", e.message || e)
  }

  // Then try Blockscout; many instances also support standard-json-input
  try {
    await hre.run("verify:verify", {
      address,
      contract: contractFullyQualifiedName,
      constructorArguments: [],
      libraries: {},
      standardJsonInput,
      network: "sepolia-blockscout",
    })
    console.log("✅ Blockscout verified via standard JSON input")
  } catch (e: any) {
    console.log("❌ Blockscout failed:", e.message || e)
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
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
  hardhat-deploy hardhat-gas-reporter hardhat-contract-sizer solidity-docgen@0.6.0-beta.36 \
  @openzeppelin/hardhat-upgrades

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
pnpm --dir apps/dao-dapp add -D eslint-plugin-react-hooks @eslint/js @typescript-eslint/parser @typescript-eslint/eslint-plugin
pnpm --dir packages/contracts add -D solhint prettier prettier-plugin-solidity

cat > apps/dao-dapp/eslint.config.js <<'EOF'
import js from '@eslint/js'
import reactHooks from 'eslint-plugin-react-hooks'
import tseslint from '@typescript-eslint/eslint-plugin'
import tsparser from '@typescript-eslint/parser'

export default [
  js.configs.recommended,
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        global: 'readonly',
        alert: 'readonly',
        TextEncoder: 'readonly',
        TextDecoder: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        fetch: 'readonly'
      }
    },
    plugins: {
      'react-hooks': reactHooks
    },
    rules: {
      ...reactHooks.configs.recommended.rules
    }
  },
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: {
          jsx: true
        }
      },
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        global: 'readonly',
        alert: 'readonly',
        TextEncoder: 'readonly',
        TextDecoder: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        fetch: 'readonly'
      }
    },
    plugins: {
      'react-hooks': reactHooks,
      '@typescript-eslint': tseslint
    },
    rules: {
      ...reactHooks.configs.recommended.rules
    }
  },
  {
    ignores: ['dist/**', 'node_modules/**', '*.config.js', 'vite.config.ts']
  }
]
EOF

cat > .prettierrc.json <<'EOF'
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "overrides": [
    { 
      "files": "*.sol", 
      "options": { 
        "plugins": ["prettier-plugin-solidity"],
        "printWidth": 120,
        "tabWidth": 4,
        "useTabs": false,
        "bracketSpacing": true,
        "explicitTypes": "always"
      } 
    }
  ]
}
EOF

cat > packages/contracts/.solhint.json <<'EOF'
{
  "extends": ["solhint:recommended"],
  "rules": {
    "func-visibility": ["error", { "ignoreConstructors": true }],
    "max-line-length": ["warn", 120],
    "natspec": "error",
    "natspec-return": "error",
    "natspec-param": "error",
    "natspec-constructor": "error",
    "natspec-function": "error",
    "natspec-event": "error",
    "natspec-modifier": "error"
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

cat > .husky/pre-push <<'EOF'
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
echo "Running pre-push checks (compile + tests)..."
echo ""

# Compile contracts
echo "Compiling contracts..."
if ! pnpm contracts:compile; then
  echo "❌ Contract compilation failed. Fix errors before pushing."
  exit 1
fi

# Run Hardhat tests
echo "Running Hardhat tests..."
if ! pnpm contracts:test; then
  echo "❌ Hardhat tests failed. Fix tests before pushing."
  exit 1
fi

# Run Foundry tests (if available)
if command -v forge >/dev/null 2>&1; then
  echo "Running Foundry tests..."
  if ! pnpm forge:test; then
    echo "❌ Foundry tests failed. Fix tests before pushing."
    exit 1
  fi
else
  echo "⚠️  Foundry not found, skipping Foundry tests"
fi

echo "✅ All pre-push checks passed!"
EOF
chmod +x .husky/pre-push

cat > .lintstagedrc.json <<'EOF'
{
  "apps/dao-dapp/**/*.{ts,tsx,js}": [
    "bash -c 'cd apps/dao-dapp && eslint --fix'",
    "prettier --write"
  ],
  "packages/contracts/**/*.sol": ["prettier --write", "solhint --fix"]
}
EOF

# Create comprehensive check script
mkdir -p scripts
cat > scripts/check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*"; }

echo "Running comprehensive safety checks..."
echo ""

# Frontend checks
info "Checking frontend..."
if pnpm --dir apps/dao-dapp exec eslint . --ext .ts,.tsx; then
  info "Frontend linting passed"
else
  err "Frontend linting failed"
  exit 1
fi

if pnpm web:build; then
  info "Frontend build passed"
else
  err "Frontend build failed"
  exit 1
fi

echo ""

# Contract checks
info "Checking contracts..."
if pnpm contracts:compile; then
  info "Contract compilation passed"
else
  err "Contract compilation failed"
  exit 1
fi

if pnpm contracts:test; then
  info "Hardhat tests passed"
else
  err "Hardhat tests failed"
  exit 1
fi

if command -v forge >/dev/null 2>&1; then
  if pnpm forge:test; then
    info "Foundry tests passed"
  else
    err "Foundry tests failed"
    exit 1
  fi
else
  warn "Foundry not found, skipping Foundry tests"
fi

echo ""
info "All checks passed! ✅"
EOF
chmod +x scripts/check.sh

# --- CI removed - all checks run locally via Husky hooks and pnpm scripts ---

# --- GitHub workflows removed - all checks and deployments run locally ---

# --- README ------------------------------------------------------------------
cat > README.md <<'EOF'
# DApp Setup (Rookie-friendly)

**Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4  
**State Management**: Zustand v4 (global state) with Storacha account/space management store  
**IPFS/IPNS**: Helia v2 (full IPFS node) + @helia/unixfs + @helia/ipns + @libp2p/crypto + @noble/curves  
**IPFS Pinning**: Storacha SDK, Pinata SDK, or Fleek Platform SDK (choose one or multiple)  
**Contracts**: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6), OpenZeppelin, TypeChain, hardhat-deploy  
**DX**: Foundry (Forge/Anvil), gas-reporter, contract-sizer, solidity-docgen (auto, opt-out), Solhint/Prettier, Husky  
**Documentation**: Comprehensive NatSpec support with linting, validation, and auto-generation (disable with `DOCS_AUTOGEN=false`)  
**Local Safety Net**: Automated checks via Husky hooks (pre-commit, pre-push) and pnpm scripts

## 1) First-time setup

Run the setup script:
```bash
bash setup.sh
```

After setup completes, you'll need to configure your environment files:

**Step 1:** Edit `apps/dao-dapp/.env.local`
- Add your `VITE_WALLETCONNECT_ID` (get one free from [WalletConnect Cloud](https://cloud.walletconnect.com))
- Add RPC URLs for the networks you want to use (defaults are provided)
- **IPFS/IPNS Configuration** (choose one or multiple pinning services):
  - **Storacha** - [Storacha](https://storacha.network) (free tier available)
    - **Setup Steps (pnpm-first):**
      1. Install CLI: `pnpm dlx @storacha/cli@latest`
      2. Create account: `storacha login your@email.com` (check email for verification link)
      3. Select a plan (Free tier available) after email verification
      4. Create a Space: `storacha space create my-space` (or use JS client in code)
    - **Alternative:** Use web console at https://console.storacha.network
    - **In Code:** Users enter their email at runtime in the DApp. Use `@storacha/client` - `const client = await create(); await client.login(email)`
    - **Note:** No environment variable needed - email is entered by users when logging in through the DApp UI
  - `VITE_PINATA_JWT` - Get from [Pinata](https://app.pinata.cloud) → API Keys → New Key (free tier available)
  - `VITE_PINATA_GATEWAY` - Get from [Pinata](https://app.pinata.cloud) → Gateways (format: fun-llama-300.mypinata.cloud)
  - `VITE_FLEEK_CLIENT_ID` - Get from [Fleek Platform](https://app.fleek.co) → Create Application → Get Client ID
  - IPFS gateway URLs are pre-configured with defaults

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

## Local Safety Net

All checks and quality gates run **locally on your machine** - no need for GitHub Actions!

### Automatic Checks (via Husky Hooks)

**Pre-commit hook** (runs automatically before every `git commit`):
- Formats code with Prettier
- Lints TypeScript/JavaScript with ESLint
- Lints Solidity with Solhint
- Formats Solidity with Forge (if Foundry is installed)
- **You can't commit broken code!**

**Pre-push hook** (runs automatically before every `git push`):
- Compiles all contracts
- Runs Hardhat tests
- Runs Foundry tests (if installed)
- **You can't push broken code!**
- Skip with `git push --no-verify` if needed

### Manual Check Commands

Run comprehensive checks anytime:

```bash
pnpm check:all        # Run all checks (frontend + contracts)
pnpm check:frontend   # Lint and build frontend only
pnpm check:contracts  # Compile and test contracts only
pnpm check:quick      # Fast checks (linting only, no tests)
pnpm check:full       # Alias for check:all
./scripts/check.sh    # Comprehensive bash script with detailed output
```

### Deploy Your App Online (Optional)

Want to share your app with the world? Deploy it to IPFS using Fleek:

**Step 1:** Go to your frontend folder
```bash
cd apps/dao-dapp
```

**Step 2:** Initialize Fleek
```bash
pnpm dlx @fleekhq/fleek-cli@0.1.8 site:init
```
This creates a `.fleek.json` file - commit it to git.

**Step 3:** Get your API key
- Go to [Fleek Dashboard](https://app.fleek.co)
- Create an account (free)
- Get your API key from settings

**Step 4:** Add it to GitHub Secrets
- Go to your GitHub repo → Settings → Secrets and variables → Actions
- Click "New repository secret"
- Name: `FLEEK_API_KEY`
- Value: paste your API key from Fleek

**That's it!** Your app will automatically deploy to IPFS whenever you push to the `main` branch. The deployment happens after all tests pass successfully.

> 💡 **Note:** No secrets are stored in your code - they're safely stored in GitHub Secrets.

## 2) Everyday commands

### Start Developing

**Frontend (web app):**
```bash
pnpm web:dev
```
Opens your app at `http://localhost:5173` - it auto-refreshes when you make changes!

**Local blockchain (for testing):**
```bash
pnpm anvil:start   # Start a local blockchain
pnpm anvil:stop    # Stop it when you're done
```
This gives you a local Ethereum network to test your contracts without spending real money.

### Run Safety Checks

**Quick checks (before committing):**
```bash
pnpm check:quick      # Fast linting checks only
```

**Full safety check (before pushing):**
```bash
pnpm check:all       # Run all checks (frontend + contracts)
# Or use the detailed script:
./scripts/check.sh   # Comprehensive check with colored output
```

**Individual checks:**
```bash
pnpm check:frontend   # Lint and build frontend
pnpm check:contracts  # Compile and test contracts
```

> 💡 **Note:** These checks run automatically via Husky hooks (pre-commit and pre-push), but you can also run them manually anytime!

### State Management with Zustand

This project uses **Zustand** for global state management. A pre-configured store is included for managing Storacha accounts and spaces.

**Storacha Store Features:**
- **Authentication**: Login/logout, multiple account support, account switching
- **Spaces Management**: Create, delete, list spaces
- **Space Contents**: Upload, delete, list files within spaces
- **Persistent State**: Authentication state persists across page refreshes (localStorage)
- **TypeScript Support**: Fully typed store with TypeScript interfaces

**Using the Storacha Store:**

```tsx
import { useStorachaStore } from '../stores'

function MyComponent() {
  // Access state
  const { currentAccount, isAuthenticated, spaces, selectedSpace } = useStorachaStore()
  
  // Access actions
  const { login, logout, fetchSpaces, createSpace, selectSpace } = useStorachaStore()
  
  // Use in your component
  return (
    <div>
      {isAuthenticated ? (
        <p>Logged in as: {currentAccount?.email}</p>
      ) : (
        <button onClick={() => login('user@example.com')}>Login</button>
      )}
    </div>
  )
}
```

**Example Component:**
See `apps/dao-dapp/src/components/StorachaManager.tsx` for a complete example showing:
- Login/logout functionality
- Multiple account switching
- Space creation and management
- File upload and content management

**Store Location:**
- Store definition: `apps/dao-dapp/src/stores/useStorachaStore.ts`
- Type definitions: `apps/dao-dapp/src/types/storacha.ts`
- Store exports: `apps/dao-dapp/src/stores/index.ts`

> 💡 **Note:** The store includes TODO comments where you need to integrate the actual `@storacha/client` SDK. The structure is ready - you just need to replace the mock implementations with real Storacha API calls.

### Working with Contracts

**Basic workflow:**
```bash
pnpm contracts:compile  # Compile your contracts (creates ABIs for frontend)
pnpm contracts:test     # Run tests
pnpm contracts:deploy   # Deploy to your configured network
```

**Verify your contracts on block explorers:**
```bash
pnpm contracts:verify              # Verify on Etherscan
pnpm contracts:verify:multi        # Try both Etherscan and Blockscout (if one fails)
pnpm contracts:verify:stdjson      # Verify using standard JSON input (for complex contracts)
pnpm contracts:verify-upgradeable  # Verify upgradeable proxy contracts
```

**Advanced features:**
```bash
pnpm contracts:debug              # Check code size and balance for any address
pnpm contracts:deploy-upgradeable # Deploy an upgradeable proxy contract
pnpm contracts:upgrade            # Upgrade an existing proxy contract
pnpm contracts:docs               # Generate documentation from your NatSpec comments
pnpm contracts:lint:natspec       # Check that your documentation is complete
```

**Foundry (alternative testing framework):**
```bash
pnpm forge:test       # Run Foundry tests
pnpm forge:fmt        # Format your Solidity code
pnpm foundry:update   # Update Foundry to latest version
```

## 3) Create Your First Contract

Let's create a simple token contract to get you started!

**Step 1:** Create the contract file
Create `packages/contracts/contracts/MyToken.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MyToken is ERC20 {
  constructor() ERC20("MyToken","MTK") { _mint(msg.sender, 1_000_000 ether); }
}
```

**Step 2:** Create the deployment script
Create `packages/contracts/deploy/01_mytoken.ts`:

```ts
import type { DeployFunction } from 'hardhat-deploy/types'
const func: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deploy } = deployments; const { deployer } = await getNamedAccounts();
  await deploy('MyToken', { from: deployer, args: [], log: true });
}
export default func; func.tags = ['MyToken'];
```

**Step 3:** Compile and deploy
```bash
pnpm contracts:compile
pnpm --filter contracts exec hardhat deploy --network sepolia --tags MyToken
```

**What happens:**
- Your contract compiles successfully ✅
- It gets deployed to Sepolia testnet ✅
- The ABI (Application Binary Interface) automatically appears in `apps/dao-dapp/src/contracts/` ✅
- You can now use it in your frontend! 🎉

## 4) Documenting Your Contracts

Good documentation helps others (and future you!) understand your code. This setup makes it easy!

### What is NatSpec?
NatSpec (Natural Language Specification) is a way to document your Solidity contracts using special comments. Think of it like JSDoc for JavaScript, but for smart contracts.

### How It Works

**Automatic documentation:**
- Every time you compile, documentation is automatically generated
- It creates nice Markdown files in `packages/contracts/docs`
- Want to skip auto-generation? Set `DOCS_AUTOGEN=false` in your environment

**Manual commands:**
```bash
pnpm contracts:docs          # Generate documentation right now
pnpm contracts:lint:natspec  # Check that all your functions are documented
```

### NatSpec Tags You Can Use:
- `@title` - Give your contract a title
- `@notice` - Explain what your contract/function does (for users)
- `@dev` - Technical details (for developers)
- `@param` - Describe each parameter
- `@return` - Explain what the function returns
- `@author` - Your name or team
- `@custom:*` - Any custom tags you want

### See It In Action
Check out `packages/contracts/contracts/ExampleToken.sol` - it has comprehensive NatSpec documentation showing you how it's done!

### Where Does It Go?
- Documentation files are saved to `packages/contracts/docs`
- They're generated automatically after each compile (unless disabled)
- You can also generate them manually anytime with `pnpm contracts:docs`

The generated docs work great with tools like:
- **solidity-docgen** - Creates Markdown docs (already included!)
- **docusaurus** - Build a full documentation website
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
echo "   - Add your VITE_WALLETCONNECT_ID (get one free from https://cloud.walletconnect.com)"
echo "   - Add IPFS/IPNS configuration (choose one or multiple):"
echo "     * Storacha: No env var needed - users enter email at runtime in DApp"
echo "       (Create account first: pnpm dlx @storacha/cli@latest && storacha login your@email.com) OR"
echo "     * VITE_PINATA_JWT (get from https://app.pinata.cloud → API Keys → New Key)"
echo "     * VITE_PINATA_GATEWAY (get from https://app.pinata.cloud → Gateways) OR"
echo "     * VITE_FLEEK_CLIENT_ID (get from https://app.fleek.co → Create Application → Get Client ID)"
echo "   - RPC URLs are pre-configured with defaults"
echo "2) Edit packages/contracts/.env.hardhat.local"
echo "   - Add your PRIVATE_KEY or MNEMONIC (for deploying contracts)"
echo "   - Add RPC URLs for networks (Sepolia, Mainnet, etc.)"
echo "   - Add ETHERSCAN_API_KEY (get one free from https://etherscan.io/apis)"
echo "3) To deploy the website locally, run \"pnpm web\:dev\" from the root directory"
echo ""
echo "💡 Local Safety Net:"
echo "   - Pre-commit hook: Automatically formats and lints code before commit"
echo "   - Pre-push hook: Automatically compiles and tests before push"
echo "   - Manual checks: Run 'pnpm check:all' anytime for full safety check"
echo ""
echo "4) To deploy the app online:"
echo "   Step 1: Create a GitHub repository"
echo "   - Go to https://github.com and sign in (or create a free account)"
echo "   - Click the '+' icon in the top right corner → 'New repository'"
echo "   - Name your repository (e.g., 'my-dao-dapp')"
echo "   - Choose 'Public' or 'Private'"
echo "   - DO NOT initialize with README, .gitignore, or license (we already have these)"
echo "   - Click 'Create repository'"
echo ""
echo "   Step 2: Sync your project to GitHub"
echo "   - In your terminal, make sure you're in the project root folder"
echo "   - Check if git is initialized: git status"
echo "   - If not initialized, run: git init"
echo "   - Add your GitHub repo as remote: git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"
echo "     (Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual GitHub username and repo name)"
echo "   - Stage all files: git add -A"
echo "   - Commit: git commit -m 'Initial commit'"
echo "   - Push to GitHub: git push -u origin main"
echo "   - Refresh your GitHub page - you should see all your files there!"
echo ""
echo "   Step 3: Set up Fleek and configure deployment"
echo "   - Go to https://app.fleek.co and sign in (or create a free account)"
echo "   - Click 'Create new - site'"
echo "   - Select code location GitHub"
echo "   - Authorize Fleek to access your GitHub account (click 'Authorize')"
echo "   - Select your repository from the list and click 'Deploy'"
echo "   - Select the 'main' branch (or your default branch name)"
echo "   - On the same configuration page, you'll see these fields:"
echo "     * 'Framework': Select 'Vite' from the dropdown (or 'Other' if Vite is not available)"
echo "     * 'Branch': Should already show 'main' (or your default branch)"
echo "     * 'Publish Directory': Enter apps/dao-dapp/dist"
echo "     * 'Build Command': Enter corepack enable && corepack prepare pnpm@10.16.1 --activate && pnpm install --frozen-lockfile=false && pnpm web:build"
echo "       (This enables Corepack, sets up pnpm, installs dependencies, then builds your app)"
echo "       (The build creates the 'dist' folder that Fleek will deploy)"
echo "     * Under advanced options,'Docker Image': Change from 'fleek/node:lts' to 'node:22'"
echo "       (This ensures Node.js version 22 is used, which your project requires)"
echo "       (If 'node:22' doesn't work, try 'fleek/node:22' or check Fleek docs for Node 22 image)"
echo "     * 'Base Directory': Leave as './' (or click 'Select' and choose the project root)"
echo "   - Scroll down to the 'Environment Variables' section (on the same page)"
echo "   - IMPORTANT: Add these environment variables BEFORE clicking 'Deploy site'"
echo "   - Click 'Add Variable' or '+' button for each variable"
echo "   - Add these variables one by one (get values from your apps/dao-dapp/.env.local file):"
echo "     * Name: VITE_WALLETCONNECT_ID"
echo "       Value: (get one free from https://cloud.walletconnect.com - sign up and create a project)"
echo "     * Name: VITE_MAINNET_RPC"
echo "       Value: https://cloudflare-eth.com (or your custom RPC)"
echo "     * Name: VITE_POLYGON_RPC"
echo "       Value: https://polygon-rpc.com (or your custom RPC)"
echo "     * Name: VITE_OPTIMISM_RPC"
echo "       Value: https://optimism.publicnode.com (or your custom RPC)"
echo "     * Name: VITE_ARBITRUM_RPC"
echo "       Value: https://arbitrum.publicnode.com (or your custom RPC)"
echo "     * Name: VITE_SEPOLIA_RPC"
echo "       Value: https://rpc.sepolia.org (or your custom RPC)"
echo "     * Note: Storacha - No env var needed (users enter email at runtime in DApp)"
echo "       OR"
echo "     * Name: VITE_PINATA_JWT"
echo "       Value: (get from https://app.pinata.cloud → API Keys → New Key)"
echo "     * Name: VITE_PINATA_GATEWAY"
echo "       Value: (get from https://app.pinata.cloud → Gateways - format: fun-llama-300.mypinata.cloud)"
echo "       OR"
echo "     * Name: VITE_FLEEK_CLIENT_ID"
echo "       Value: (get from https://app.fleek.co → Create Application → Get Client ID)"
echo "     * Name: VITE_FLEEK_GATEWAY"
echo "       Value: https://ipfs.fleek.co"
echo "     * Name: VITE_IPFS_GATEWAY_1"
echo "       Value: https://dweb.link"
echo "     * Name: VITE_IPFS_GATEWAY_2"
echo "       Value: https://ipfs.io"
echo "     * Name: VITE_IPFS_GATEWAY_3"
echo "       Value: https://cloudflare-ipfs.com"
echo "     * Name: VITE_IPNS_ENABLED"
echo "       Value: true"
echo "   - (If you see 'Hide advanced options', click it to see more fields if needed)"
echo ""
echo "   Step 4: Deploy manually (first time)"
echo "   - Click 'Deploy Site' or 'Deploy' button at the bottom of the Fleek page"
echo "   - Wait for the build to complete (you'll see progress in Fleek dashboard)"
echo "   - Once done, you'll get a URL like: your-site.on.fleek.co"
echo "   - Your app is now live! Share the URL with anyone 🌐"
echo ""
echo "   Troubleshooting: If deployment fails or website is blank:"
echo "   - Go to your site in Fleek dashboard → 'Deployments' tab"
echo "   - Click on the failed deployment to see details"
echo "   - Click on 'Build Logs' step to see error messages"
echo "   - Common issues and fixes:"
echo "     * If website deploys but shows blank page:"
echo "       → Go to Settings → Environment Variables"
echo "       → Make sure all VITE_* variables are added:"
echo "         - VITE_WALLETCONNECT_ID (required)"
echo "         - (VITE_PINATA_JWT + VITE_PINATA_GATEWAY) or VITE_FLEEK_CLIENT_ID (for IPFS pinning)"
echo "         - Note: Storacha doesn't need env vars (users enter email at runtime)"
echo "         - All RPC URLs (required for blockchain connections)"
echo "       → Redeploy after adding missing variables"
echo "     * If you see 'Unsupported engine' or wrong Node version:"
echo "       → Go to Settings → Make sure 'Docker Image' is set to 'fleek/node:22' or 'node:22'"
echo "     * If you see 'tsc: not found' or 'node_modules missing':"
echo "       → Make sure 'Build Command' includes all steps: corepack enable && corepack prepare pnpm@10.16.1 --activate && pnpm install --frozen-lockfile=false && pnpm web:build"
echo "     * If you see 'Dist directory does not exist' AFTER build completes:"
echo "       → Check that 'Publish Directory' is exactly 'apps/dao-dapp/dist' (not just 'dist')"
echo "       → Check that 'Base Directory' is './' (project root)"
echo "       → The build command should CREATE the dist folder - if it doesn't exist, the build failed"
echo "   - After fixing, click 'Redeploy' button to try again"
echo ""
echo "   Step 5: Set up automatic deployment via GitHub Actions (optional but recommended)"
echo "   - This allows your app to auto-deploy when you push code to GitHub"
echo "   - Go to https://app.fleek.co → Your site → Settings → API Keys"
echo "   - Click 'Generate API Key' or copy your existing API key"
echo "   - Go to your GitHub repository page"
echo "   - Click 'Settings' tab (top menu)"
echo "   - In the left sidebar, click 'Secrets and variables' → 'Actions'"
echo "   - Click 'New repository secret' button"
echo "   - Name: FLEEK_API_KEY"
echo "   - Value: Paste the API key you copied from Fleek"
echo "   - Click 'Add secret'"
echo "   - Now go to your project folder in terminal"
echo "   - Navigate to apps/dao-dapp: cd apps/dao-dapp"
echo "   - Run: pnpm dlx @fleekhq/fleek-cli@0.1.8 site:init"
echo "   - This creates a .fleek.json file"
echo "   - Go back to project root: cd ../.."
echo "   - Commit and push: git add apps/dao-dapp/.fleek.json && git commit -m 'Add Fleek config' && git push"
echo "   - Now every time you push to main branch, GitHub Actions will automatically deploy your app!"