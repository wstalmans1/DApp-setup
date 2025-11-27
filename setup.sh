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
            <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Starter</p>
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
    branches: [main]

env:
  NODE_VERSION: "22"
  PNPM_VERSION: "10.16.1"

jobs:
  lint-test-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: pnpm

      - name: Enable Corepack
        run: corepack enable

      - name: Use pnpm ${{ env.PNPM_VERSION }}
        run: corepack prepare pnpm@${{ env.PNPM_VERSION }} --activate

      - name: Install dependencies
        run: pnpm install --frozen-lockfile=false

      - name: Lint frontend
        run: pnpm dlx eslint apps/dao-dapp --ext .ts,.tsx

      - name: Build frontend
        run: pnpm web:build

      - name: Compile contracts (Hardhat)
        run: pnpm contracts:compile

      - name: Hardhat tests
        run: pnpm --filter contracts test

      - name: Foundry tests
        run: |
          curl -L https://foundry.paradigm.xyz | bash
          ~/.foundry/bin/foundryup
          forge test -vvv
        working-directory: packages/contracts

      - name: Solhint (non-blocking)
        run: pnpm --filter contracts exec solhint 'contracts/**/*.sol' || true
EOF

# --- Deploy to Fleek (IPFS) --------------------------------------------------
cat > .github/workflows/deploy-fleek.yml <<'EOF'
name: Deploy (Fleek IPFS)

on:
  workflow_dispatch:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

env:
  NODE_VERSION: "22"
  PNPM_VERSION: "10.16.1"

jobs:
  deploy:
    if: github.event_name == 'workflow_dispatch' || (github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.head_branch == 'main')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event_name == 'workflow_run' && github.event.workflow_run.head_commit.id || github.sha }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: pnpm

      - name: Enable Corepack
        run: corepack enable

      - name: Use pnpm ${{ env.PNPM_VERSION }}
        run: corepack prepare pnpm@${{ env.PNPM_VERSION }} --activate

      - name: Install dependencies
        run: pnpm install --frozen-lockfile=false

      - name: Build frontend
        run: pnpm web:build

      - name: Ensure Fleek config exists
        run: |
          test -f apps/dao-dapp/.fleek.json || {
            echo "::error::Missing apps/dao-dapp/.fleek.json. Run 'pnpm dlx @fleekhq/fleek-cli@0.1.8 site:init' inside apps/dao-dapp and commit the file."
            exit 1
          }

      - name: Deploy to Fleek (IPFS)
        uses: FleekHQ/action-deploy@v1
        with:
          apiKey: ${{ secrets.FLEEK_API_KEY }}
          workDir: apps/dao-dapp
          commitHash: ${{ github.event_name == 'workflow_run' && github.event.workflow_run.head_commit.id || github.sha }}
EOF

# --- README ------------------------------------------------------------------
cat > README.md <<'EOF'
# DApp Setup (Rookie-friendly)

**Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v4  
**Contracts**: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6), OpenZeppelin, TypeChain, hardhat-deploy  
**DX**: Foundry (Forge/Anvil), gas-reporter, contract-sizer, solidity-docgen (auto, opt-out), Solhint/Prettier, Husky  
**Documentation**: Comprehensive NatSpec support with linting, validation, and auto-generation (disable with `DOCS_AUTOGEN=false`)  
**CI**: GitHub Actions

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

## CI & deployment

### Automated Testing (CI)
When you push code or create a pull request, GitHub Actions automatically:
- Installs all dependencies
- Lints and builds your frontend
- Compiles and tests your contracts (Hardhat)
- Runs Foundry tests
- Checks code quality with Solhint

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
echo "2) Edit packages/contracts/.env.hardhat.local"
echo "3) To deploy the website locally, run \"pnpm web\:dev\" from the root directory"
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
echo "       → Make sure all VITE_* variables are added (especially VITE_WALLETCONNECT_ID)"
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
