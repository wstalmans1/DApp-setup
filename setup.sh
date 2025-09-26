#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# setup.sh — Node 22 + React 18 + wagmi/RainbowKit + Tailwind v4 + Hardhat 3 (ESM)
#           + OpenZeppelin + Foundry (Forge/Anvil) + TypeChain + HH plugins
#           + Solhint/Prettier + Husky + CI-ready DX
#
# Rookie-proof: will AUTO-STOP any running `anvil` before Foundry updates, so it won't hang.
#
# Usage (from an EMPTY folder, or rerun safely to repair an existing setup):
#   bash setup.sh
# -----------------------------------------------------------------------------

# --- Helpers -----------------------------------------------------------------------
info () { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok   () { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn () { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err  () { printf "\033[1;31m[x]\033[0m %s\n" "$*"; }

stop_anvil() {
  # Try hard to stop any running anvil processes, without failing the script.
  local attempts=0
  local max_attempts=5
  if pgrep -f '^anvil( |$)' >/dev/null 2>&1; then
    warn "Detected running anvil; attempting to stop it..."
  fi
  while pgrep -f '^anvil( |$)' >/dev/null 2>&1 && [ $attempts -lt $max_attempts ]; do
    attempts=$((attempts + 1))
    # Prefer pkill; fall back to killall; then manual kill.
    pkill -f '^anvil( |$)' >/dev/null 2>&1 || true
    killall anvil >/dev/null 2>&1 || true
    # If still running, send SIGKILL to remaining PIDs.
    if pgrep -f '^anvil( |$)' >/dev/null 2>&1; then
      pids=$(pgrep -f '^anvil( |$)' || true)
      if [ -n "${pids:-}" ]; then
        warn "Forcing stop of anvil PIDs: $pids"
        kill -9 $pids >/dev/null 2>&1 || true
      fi
    fi
    sleep 1
  done
  if pgrep -f '^anvil( |$)' >/dev/null 2>&1; then
    err "Could not stop running anvil after $max_attempts attempts. Please close it manually and re-run."
    exit 1
  else
    ok "anvil is not running."
  fi
}

# --- Corepack & pnpm ---------------------------------------------------------------
command -v corepack >/dev/null 2>&1 || {
  err "Corepack not found. Install Node.js >= 22 and retry."
  exit 1
}
corepack enable
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
corepack prepare pnpm@10.16.1 --activate

# Pin Node for shells
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

    "anvil:start": "anvil --block-time 1",
    "anvil:stop": "pkill -f '^anvil( |$)' || killall anvil || true",
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

# --- App scaffold (Vite + React + TS) ----------------------------------------------
mkdir -p apps
if [ -d "apps/dao-dapp" ]; then
  info "apps/dao-dapp already exists; keeping it and ensuring deps/configs are correct."
else
  pnpm create vite@6 apps/dao-dapp -- --template react-ts --no-git --package-manager pnpm
fi

# React 18 (wagmi peers expect <=18)
pnpm --dir apps/dao-dapp add react@18.3.1 react-dom@18.3.1
pnpm --dir apps/dao-dapp add -D @types/react@18.3.12 @types/react-dom@18.3.1

# Web3 + data
pnpm --dir apps/dao-dapp add @rainbow-me/rainbowkit@~2.2.8 wagmi@~2.16.9 viem@~2.37.6 @tanstack/react-query@~5.90.2
pnpm --dir apps/dao-dapp add @tanstack/react-query-devtools@~5.90.2 zod@~3.22.0

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

# Contracts artifacts bucket (used by the app)
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

# main.tsx providers
cat > a
