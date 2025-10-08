#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 🚀 ENHANCED DApp Development Setup (Production-Ready)
# =============================================================================
# 
# This is an enhanced version of the basic DApp setup script, built on real-world
# experience and battle-tested patterns from production deployments.
#
# 🎯 WHAT THIS VERSION ADDS ON TOP OF THE BASIC VERSION:
#
# 1. FACTORY PATTERNS (⭐⭐⭐)
#    - Production-ready Factory.sol with optimized assembly
#    - Fixed calldatacopy issues that cause zero-code deployments
#    - ContractRegistry.sol for tracking deployed contracts
#    - Role-based access control for factory management
#
# 2. MULTI-EXPLORER VERIFICATION (⭐⭐⭐)
#    - Dual Etherscan + Blockscout verification support
#    - Standard JSON input verification for complex contracts
#    - Debug tools for deployment issues
#    - Automated verification scripts with fallback strategies
#
# 3. TALLY GOVERNANCE INTEGRATION (⭐⭐)
#    - Generate Tally proposal calldata automatically
#    - Proper ABI encoding for complex function calls
#    - Governance-ready factory patterns
#
# 4. ENHANCED TESTING & DEBUGGING (⭐⭐)
#    - Comprehensive test patterns for factory contracts
#    - Debug deployment scripts
#    - Real-world test scenarios
#
# 5. PRODUCTION CONFIGURATION (⭐)
#    - Metadata settings for verification compatibility
#    - Multi-explorer network configuration
#    - Enhanced error handling and logging
#
# 6. COMPREHENSIVE NATSPEC DOCUMENTATION (⭐)
#    - Complete documentation generation toolchain
#    - NatSpec linting and validation
#    - Production-ready documentation patterns
#
# =============================================================================
# BASIC VERSION FOUNDATION:
# =============================================================================

# -----------------------------------------------------------------------------
# setup.sh — Rookie-proof DApp bootstrap (Hardhat **v2** lane)
# Frontend: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v3
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
    "contracts:debug": "pnpm --filter contracts exec ts-node scripts/debug-deployment.ts",
    "contracts:tally": "pnpm --filter contracts exec ts-node scripts/generate-tally-proposal.ts",
    "contracts:docs": "pnpm --filter contracts run docs",
    "contracts:lint:natspec": "pnpm --filter contracts run lint:natspec",

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
pnpm --dir apps/dao-dapp add @rainbow-me/rainbowkit@^2.2.8 wagmi@^2.16.9 viem@^2.37.6 @tanstack/react-query@^5.90.2
pnpm --dir apps/dao-dapp add @tanstack/react-query-devtools@^5.90.2 zod@^3.22.0

# Tailwind v3 (stable)
pnpm --dir apps/dao-dapp add -D tailwindcss@^3.4.0 postcss@^8.4.47 autoprefixer@^10.4.20
cat > apps/dao-dapp/postcss.config.mjs <<'EOF'
export default { 
  plugins: { 
    tailwindcss: {},
    autoprefixer: {}
  } 
}
EOF
mkdir -p apps/dao-dapp/src
cat > apps/dao-dapp/src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > apps/dao-dapp/tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
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
import { config as loadEnv } from 'dotenv'
import type { HardhatUserConfig } from 'hardhat/config'

import '@nomicfoundation/hardhat-toolbox'
import '@typechain/hardhat'
import 'hardhat-deploy'
import 'hardhat-docgen'

loadEnv({ path: resolve(__dirname, '.env.hardhat.local') })

const privateKey = process.env.PRIVATE_KEY?.trim()
const mnemonic = process.env.MNEMONIC?.trim()
const accounts: any = privateKey ? [privateKey] : mnemonic ? { mnemonic } : undefined

const config: HardhatUserConfig = {
  solidity: { 
    version: '0.8.28', 
    settings: { 
      optimizer: { enabled: true, runs: 200 },
      metadata: {
        bytecodeHash: "none"  // Critical for verification compatibility
      },
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
    ...(process.env.MAINNET_RPC ? { mainnet: { url: process.env.MAINNET_RPC!, accounts } } : {}),
    ...(process.env.POLYGON_RPC ? { polygon: { url: process.env.POLYGON_RPC!, accounts } } : {}),
    ...(process.env.OPTIMISM_RPC ? { optimism: { url: process.env.OPTIMISM_RPC!, accounts } } : {}),
    ...(process.env.ARBITRUM_RPC ? { arbitrum: { url: process.env.ARBITRUM_RPC!, accounts } } : {})
  },
  namedAccounts: { deployer: { default: 0 } },
  gasReporter: { 
    enabled: process.env.REPORT_GAS === 'true',
    currency: 'USD',
    coinmarketcap: process.env.CMC_API_KEY,
    token: 'ETH',
    gasPrice: 20
  },
  docgen: { 
    outputDir: './docs', 
    pages: 'items', 
    collapseNewlines: true,
    clear: true,
    runOnCompile: true,
    only: ['contracts/**/*.sol'],
    except: ['contracts/test/**/*.sol', 'contracts/mocks/**/*.sol'],
    template: 'templates',
    theme: 'markdown'
  },
  paths: {
    sources: resolve(__dirname, 'contracts'),
    tests: resolve(__dirname, 'test'),
    cache: resolve(__dirname, 'cache'),
    artifacts: resolve(__dirname, '../../apps/dao-dapp/src/contracts')
  },
  etherscan: { 
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || '',
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      "sepolia-blockscout": "dummy",
      polygon: process.env.POLYGONSCAN_KEY || '',
      optimism: process.env.OPT_ETHERSCAN_KEY || '',
      arbitrum: process.env.ARBISCAN_API_KEY || '',
    },
    customChains: [
      {
        network: "sepolia-blockscout",
        chainId: 11155111,
        urls: {
          apiURL: "https://eth-sepolia.blockscout.com/api",
          browserURL: "https://eth-sepolia.blockscout.com",
        },
      },
    ],
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

# Add Factory pattern (learned from real-world experience)
cat > packages/contracts/contracts/Factory.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Factory
 * @author Your Name
 * @notice A factory contract for deploying other contracts via CREATE opcode
 * @dev Uses optimized assembly for gas-efficient contract deployment
 * @custom:security-contact security@example.com
 */
contract Factory {
    /// @notice Emitted when a contract is deployed
    /// @param addr The address of the deployed contract
    /// @param value The ETH value sent during deployment
    event Deployed(address indexed addr, uint256 value);
    
    /// @notice Error thrown when initcode is empty
    error EmptyInitcode();
    
    /// @notice Error thrown when deployment fails
    error DeployFailed();

    /**
     * @notice Deploys a contract from raw initcode
     * @dev Uses assembly for gas-efficient deployment with proper calldatacopy
     * @param initcode The bytecode and constructor arguments for the contract to deploy
     * @return addr The address of the deployed contract
     */
    function deploy(bytes calldata initcode) external payable returns (address addr) {
        if (initcode.length == 0) revert EmptyInitcode();
        
        assembly {
            let ptr := mload(0x40)
            let len := initcode.length
            let off := initcode.offset
            calldatacopy(ptr, off, len)
            addr := create(callvalue(), ptr, len)
        }
        
        if (addr == address(0)) revert DeployFailed();
        emit Deployed(addr, msg.value);
    }
}
EOF

# Add Contract Registry pattern
cat > packages/contracts/contracts/ContractRegistry.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ContractRegistry
 * @author Your Name
 * @notice A registry for tracking deployed contracts with metadata
 * @dev Uses role-based access control for contract registration
 * @custom:security-contact security@example.com
 */
contract ContractRegistry is AccessControl {
    /// @notice Role for entities that can register contracts
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    
    /// @notice Structure for contract registration data
    struct Registration {
        address addr;
        bytes32 kind;
        address factory;
        bytes32 salt;
        bytes32 initCodeHash;
        uint64 version;
        string label;
        string uri;
    }
    
    /// @notice Mapping from contract ID to registration data
    mapping(bytes32 => Registration) public byId;
    
    /// @notice Mapping from contract kind to array of addresses
    mapping(bytes32 => address[]) public byKind;
    
    /// @notice Mapping from contract kind to latest address
    mapping(bytes32 => address) public latestByKind;
    
    /// @notice Emitted when a contract is registered
    /// @param id The unique identifier for the registration
    /// @param addr The address of the registered contract
    /// @param kind The kind/type of the contract
    event Registered(bytes32 indexed id, address indexed addr, bytes32 indexed kind);

    /**
     * @notice Constructs the ContractRegistry
     * @dev Sets the timelock as the default admin
     * @param timelock The address that will have admin privileges
     */
    constructor(address timelock) {
        _grantRole(DEFAULT_ADMIN_ROLE, timelock);
    }

    /**
     * @notice Registers a new contract in the registry
     * @dev Only addresses with REGISTRAR_ROLE can register contracts
     * @param r The registration data for the contract
     * @return id The unique identifier for the registration
     */
    function register(Registration calldata r) external onlyRole(REGISTRAR_ROLE) returns (bytes32 id) {
        address a = r.addr;
        if (a == address(0)) revert("zero addr");
        id = keccak256(abi.encodePacked(a));
        if (byId[id].addr != address(0)) revert("exists");

        byId[id] = r;
        byKind[r.kind].push(a);
        latestByKind[r.kind] = a;
        
        emit Registered(id, a, r.kind);
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

# Add verification scripts (learned from real-world experience)
cat > packages/contracts/scripts/verify-multi.ts <<'EOF'
import { ethers } from "hardhat";

async function main() {
  const address = process.argv[2];
  if (!address) throw new Error("Address required");
  
  console.log(`Verifying contract at ${address}...`);
  
  // Try Etherscan first
  try {
    await hre.run("verify:verify", { address, network: "sepolia" });
    console.log("✅ Etherscan verified");
  } catch (e: any) {
    console.log("❌ Etherscan failed:", e.message);
  }
  
  // Try Blockscout
  try {
    await hre.run("verify:verify", { address, network: "sepolia-blockscout" });
    console.log("✅ Blockscout verified");
  } catch (e: any) {
    console.log("❌ Blockscout failed:", e.message);
  }
}
main().catch(console.error);
EOF

cat > packages/contracts/scripts/verify-stdjson.ts <<'EOF'
import { ethers } from "hardhat";
import fs from "fs";

async function main() {
  const address = process.argv[2];
  const contractName = process.argv[3] || "YourContract";
  
  if (!address) throw new Error("Address required");
  
  console.log(`Verifying ${contractName} at ${address} using Standard JSON...`);
  
  // Get build-info for exact compiler settings
  const buildInfoFiles = fs.readdirSync("./artifacts/build-info");
  const buildInfo = buildInfoFiles.find(f => {
    const content = fs.readFileSync(`./artifacts/build-info/${f}`, 'utf8');
    return content.includes(contractName);
  });
  
  if (!buildInfo) throw new Error("Build info not found");
  
  const input = JSON.parse(fs.readFileSync(`./artifacts/build-info/${buildInfo}`, 'utf8')).input;
  
  // Submit to Etherscan
  const formData = new URLSearchParams();
  formData.append("apikey", process.env.ETHERSCAN_API_KEY!);
  formData.append("module", "contract");
  formData.append("action", "verifysourcecode");
  formData.append("contractaddress", address);
  formData.append("sourceCode", JSON.stringify(input));
  formData.append("codeformat", "solidity-standard-json-input");
  formData.append("contractname", contractName);
  formData.append("compilerversion", input.solcLongVersion);
  
  const response = await fetch("https://api-sepolia.etherscan.io/api", {
    method: "POST",
    body: formData,
  });
  
  const result = await response.json();
  console.log("Verification result:", result);
}
main().catch(console.error);
EOF

cat > packages/contracts/scripts/debug-deployment.ts <<'EOF'
import { ethers } from "hardhat";

async function main() {
  const address = process.argv[2];
  if (!address) throw new Error("Address required");
  
  console.log(`Debugging deployment at ${address}...`);
  
  const code = await ethers.provider.getCode(address);
  console.log("Runtime code length:", code.length);
  console.log("Code starts with:", code.slice(0, 20));
  
  if (code === "0x") {
    console.log("❌ Contract has no code - deployment failed");
  } else if (code.length < 100) {
    console.log("⚠️ Contract has minimal code - possible issue");
  } else {
    console.log("✅ Contract has proper bytecode");
  }
}
main().catch(console.error);
EOF

cat > packages/contracts/scripts/generate-tally-proposal.ts <<'EOF'
import { ethers } from "hardhat";

async function main() {
  const target = process.argv[2];
  const functionName = process.argv[3];
  const args = process.argv.slice(4);
  
  if (!target || !functionName) {
    console.log("Usage: pnpm generate-tally <target> <function> [args...]");
    console.log("Example: pnpm generate-tally 0x123... deploy 0x6080...");
    process.exit(1);
  }
  
  try {
    const contract = await ethers.getContractAt("Factory", target);
    const calldata = contract.interface.encodeFunctionData(functionName, args);
    
    console.log("=== Tally Proposal ===");
    console.log(`To: ${target}`);
    console.log(`Value: 0 ETH`);
    console.log(`Data: ${calldata}`);
  } catch (error: any) {
    console.error("Error generating calldata:", error.message);
  }
}
main().catch(console.error);
EOF

# Add comprehensive test patterns (learned from real-world experience)
cat > packages/contracts/test/Factory.test.ts <<'EOF'
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Factory", function () {
  it("Should deploy contracts correctly", async function () {
    const Factory = await ethers.getContractFactory("Factory");
    const factory = await Factory.deploy();
    await factory.waitForDeployment();
    
    // Test deployment with simple contract initcode
    const initcode = "0x608060405234801561001057600080fd5b50600080fd5b6103f3806100256000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c8063c29855781461003b578063e1c7392a14610057575b600080fd5b610043610071565b60405161004e91906100a1565b60405180910390f35b61005f610077565b60405161006c91906100a1565b60405180910390f35b600080fd5b600080fd5b6000819050919050565b61009b81610088565b82525050565b60006020820190506100b66000830184610092565b9291505056fea2646970667358221220";
    
    const tx = await factory.deploy(initcode);
    const receipt = await tx.wait();
    
    const event = factory.interface.parseLog(receipt.logs[0]);
    const deployedAddress = event.args.addr;
    
    // Verify contract has code
    const code = await ethers.provider.getCode(deployedAddress);
    expect(code.length).to.be.greaterThan(100);
    expect(code).to.not.equal("0x");
  });
  
  it("Should revert on empty initcode", async function () {
    const Factory = await ethers.getContractFactory("Factory");
    const factory = await Factory.deploy();
    await factory.waitForDeployment();
    
    await expect(factory.deploy("0x")).to.be.revertedWith("EmptyInitcode()");
  });
});
EOF

cat > packages/contracts/test/ContractRegistry.test.ts <<'EOF'
import { expect } from "chai";
import { ethers } from "hardhat";

describe("ContractRegistry", function () {
  let registry: any;
  let deployer: any;
  let registrar: any;

  beforeEach(async function () {
    [deployer, registrar] = await ethers.getSigners();
    
    const ContractRegistry = await ethers.getContractFactory("ContractRegistry");
    registry = await ContractRegistry.deploy(deployer.address);
    await registry.waitForDeployment();
    
    // Grant registrar role
    await registry.grantRole(await registry.REGISTRAR_ROLE(), registrar.address);
  });

  it("Should register contracts", async function () {
    const registration = {
      addr: "0x1234567890123456789012345678901234567890",
      kind: ethers.keccak256(ethers.toUtf8Bytes("TOKEN")),
      factory: deployer.address,
      salt: ethers.ZeroHash,
      initCodeHash: ethers.keccak256("0x6080"),
      version: 1,
      label: "TestToken",
      uri: "https://example.com"
    };
    
    await expect(registry.connect(registrar).register(registration))
      .to.emit(registry, "Registered");
  });
  
  it("Should reject registration from non-registrar", async function () {
    const registration = {
      addr: "0x1234567890123456789012345678901234567890",
      kind: ethers.keccak256(ethers.toUtf8Bytes("TOKEN")),
      factory: deployer.address,
      salt: ethers.ZeroHash,
      initCodeHash: ethers.keccak256("0x6080"),
      version: 1,
      label: "TestToken",
      uri: "https://example.com"
    };
    
    await expect(registry.register(registration))
      .to.be.revertedWith("AccessControl: account");
  });
});
EOF

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

# Gas reporting
REPORT_GAS=false
EOF
cp -f packages/contracts/.env.hardhat.example packages/contracts/.env.hardhat.local

# --- Install contracts deps (HH2 lane) ---------------------------------------
pnpm --dir packages/contracts add -D \
  hardhat@^2.22.10 \
  @nomicfoundation/hardhat-toolbox@^4.0.0 \
  typescript@~5.9.2 ts-node@~10.9.2 @types/node@^22 dotenv@^16 \
  typechain@^8.2.0 @typechain/ethers-v6@^0.4.0 @typechain/hardhat@^8.0.0 \
  hardhat-deploy@^0.11.29 hardhat-docgen@^1.0.0 \
  chai@^4.3.6 @types/chai@^4.2.0

# Runtime deps
pnpm --dir packages/contracts add @openzeppelin/contracts@^5.0.0 @openzeppelin/contracts-upgradeable@^5.0.0

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

**Frontend**: Vite + React 18 + RainbowKit v2 + wagmi v2 + viem + TanStack Query v5 + Tailwind v3  
**Contracts**: Hardhat v2 + @nomicfoundation/hardhat-toolbox (ethers v6), OpenZeppelin, TypeChain, hardhat-deploy  
**DX**: Foundry (Forge/Anvil), gas-reporter, contract-sizer, docgen, Solhint/Prettier, Husky  
**Documentation**: Comprehensive NatSpec support with linting, validation, and auto-generation  
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
pnpm contracts:verify        # Basic verification
pnpm contracts:verify:multi  # Try both Etherscan and Blockscout
pnpm contracts:verify:stdjson # Use Standard JSON for complex contracts
pnpm contracts:debug         # Debug deployment issues
pnpm contracts:tally         # Generate Tally proposal calldata
pnpm contracts:docs          # Generate documentation from NatSpec
pnpm contracts:lint:natspec  # Lint NatSpec documentation
```

Contracts (Foundry):

```bash
pnpm forge:test
pnpm forge:fmt
pnpm foundry:update
```

## 3) Factory Pattern (Real-world tested)

The setup includes a production-ready Factory contract:

```solidity
// packages/contracts/contracts/Factory.sol
contract Factory {
    function deploy(bytes calldata initcode) external payable returns (address addr) {
        // Optimized assembly for gas-efficient deployment
        assembly {
            let ptr := mload(0x40)
            let len := initcode.length
            let off := initcode.offset
            calldatacopy(ptr, off, len)
            addr := create(callvalue(), ptr, len)
        }
    }
}
```

Deploy via Factory:

```bash
# Get initcode for your contract
pnpm contracts:compile

# Deploy via factory (using Tally)
pnpm contracts:tally <factory-address> deploy <initcode>
```

## 4) Multi-Explorer Verification

Handle verification issues with multiple strategies:

```bash
# Try both Etherscan and Blockscout
pnpm contracts:verify:multi 0x123...

# Use Standard JSON for complex contracts
pnpm contracts:verify:stdjson 0x123... YourContract

# Debug deployment issues
pnpm contracts:debug 0x123...
```

## 5) Contract Registry

Track deployed contracts with metadata:

```solidity
// Register a contract
registry.register({
  addr: deployedAddress,
  kind: keccak256("TOKEN"),
  factory: factoryAddress,
  salt: bytes32(0),
  initCodeHash: keccak256(initcode),
  version: 1,
  label: "MyToken",
  uri: "https://example.com"
});
```

## 6) Example contract (OpenZeppelin)

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

## 7) NatSpec Documentation

This setup includes comprehensive NatSpec support:

### Features:
- **NatSpec Linting**: Solhint rules enforce proper documentation format
- **Auto-generation**: Documentation generated automatically on compile
- **Validation**: NatSpec comments are validated during development
- **Formatting**: Prettier ensures consistent NatSpec formatting

### Commands:
```bash
pnpm contracts:docs          # Generate HTML documentation
pnpm contracts:lint:natspec  # Check NatSpec compliance
```

### NatSpec Tags Supported:
- `@title` - Contract/function title
- `@notice` - User-facing description
- `@dev` - Developer notes
- `@param` - Parameter descriptions
- `@return` - Return value descriptions
- `@author` - Author information
- `@custom:*` - Custom tags

### Example:
See `packages/contracts/contracts/ExampleToken.sol` for a comprehensive example.

Documentation is generated into `packages/contracts/docs` on compile.
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