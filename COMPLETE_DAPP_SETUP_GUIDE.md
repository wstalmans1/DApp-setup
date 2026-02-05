# 🚀 Complete DApp Development Guide - Best Practices & Setup Instructions

This comprehensive guide combines **best practices** and **setup instructions** for building production-ready Ethereum DApps using **Wagmi v2.5+**, **Viem**, **Zustand**, **TanStack Query v5**, and **Hardhat**.

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [Core Principles](#-core-principles)
3. [Project Setup](#-project-setup)
4. [Configuration](#-configuration)
5. [Smart Contract Development](#-smart-contract-development)
6. [Frontend Development](#-frontend-development)
7. [Best Practices](#-best-practices)
8. [Advanced Patterns](#-advanced-patterns)
9. [Real-Time Event System](#-real-time-event-system)
10. [Transaction Overlay System](#-transaction-overlay-system)
11. [Deployment](#-deployment)
12. [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### Minimal Setup (4 Steps)
```bash
# 1. Create project
pnpm create vite@latest my-dapp --template react-ts
cd my-dapp

# 2. Install dependencies
pnpm add wagmi viem @tanstack/react-query @rainbow-me/rainbowkit
pnpm add -D hardhat @nomicfoundation/hardhat-toolbox

# 3. Setup (see detailed sections below)
# - Configure Vite, TypeScript, Tailwind
# - Setup Wagmi + TanStack Query
# - Initialize Hardhat

# 4. Start developing
pnpm dev
```

### Comprehensive Setup (14 Steps)
Follow the detailed setup instructions in the [Project Setup](#-project-setup) section below.

---

## ✅ Core Principles

- Always write **network-aware, stale-resistant, event-driven** UI logic
- Favor **query-driven rendering** over manual state management
- Prevent stale data via **scopeKey + event-based invalidation**
- Structure logic around **chain separation** and **chain guards**
- **Avoid Zustand for server-derived data**; use it for local UI state only

---

## 🏗️ Project Setup

### Prerequisites
- **Node.js** 18+ and **pnpm** installed
- **Cursor IDE** with TypeScript support
- **Git** for version control
- **WalletConnect Project ID** (get from [WalletConnect Cloud](https://cloud.walletconnect.com/))
- **Alchemy API Key** (get from [Alchemy](https://www.alchemy.com/))

### Step 1: Initialize Project
```bash
mkdir my-dapp
cd my-dapp
pnpm init
```

### Step 2: Install Dependencies
```bash
# Core React and build tools
pnpm add react@18.2.0 react-dom@18.2.0 react-router-dom@6.20.0

# Blockchain and wallet integration
pnpm add wagmi@2.5.0 viem@2.7.0 @rainbow-me/rainbowkit@2.0.0

# State management and data fetching
pnpm add @tanstack/react-query@^5.85.5 zustand@4.4.7

# Node.js polyfills for browser
pnpm add buffer@^6.0.3 process@^0.11.10 util@^0.12.5

# Development dependencies
pnpm add -D @vitejs/plugin-react@4.2.1 vite@5.4.19 typescript@5.2.2
pnpm add -D @types/react@18.2.43 @types/react-dom@18.2.17 @types/node@24.3.0
pnpm add -D tailwindcss@3.3.6 autoprefixer@10.4.16 postcss@8.4.32
pnpm add -D @tanstack/react-query-devtools@^5.85.5
pnpm add -D eslint@8.55.0 @typescript-eslint/eslint-plugin@6.14.0 @typescript-eslint/parser@6.14.0
pnpm add -D eslint-plugin-react-hooks@4.6.0 eslint-plugin-react-refresh@0.4.5

# Smart contract development
pnpm add -D hardhat@^2.26.1 @nomicfoundation/hardhat-toolbox@^6.1.0
pnpm add -D @openzeppelin/contracts@^5.4.0 @openzeppelin/contracts-upgradeable@^5.4.0
pnpm add -D hardhat-storage-layout@^0.1.7
```

### Step 3: Create Directory Structure
```bash
mkdir -p src/{components,hooks,config,lib,constants,contexts,stores,utils,abis,realtime,contracts}
mkdir -p src/components/{ui,examples}
mkdir -p public
mkdir -p contracts scripts test
```

**Important**: Create `public/_redirects` file for SPA routing on static hosts:
```
/*    /index.html   200
```

This ensures BrowserRouter works correctly on static hosting platforms (Fleek, Vercel, Netlify, IPFS).

---

## ⚙️ Configuration

### TypeScript Configuration (`tsconfig.json`)
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src", "vite-env.d.ts"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### Vite Configuration (`vite.config.ts`)
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, writeFileSync, existsSync } from 'fs'
import { join } from 'path'

// Simple build counter - much more reliable than git commands
function getBuildNumber(): number {
  const counterFile = join(process.cwd(), '.build-counter')
  
  try {
    if (existsSync(counterFile)) {
      const current = parseInt(readFileSync(counterFile, 'utf8')) || 0
      const next = current + 1
      writeFileSync(counterFile, next.toString())
      return next
    } else {
      // First build
      writeFileSync(counterFile, '1')
      return 1
    }
  } catch (error) {
    console.warn('⚠️ Could not read/write build counter, using timestamp fallback')
    return Math.floor(Date.now() / 1000)
  }
}

const buildNumber = getBuildNumber()
console.log(`🚀 Build #${buildNumber}`)

export default defineConfig(({ mode }) => {
  // Build-time validation for required environment variables
  if (mode === 'production' && !process.env.VITE_ALCHEMY_API_KEY) {
    throw new Error('VITE_ALCHEMY_API_KEY is required for production builds');
  }

  return {
    plugins: [react()],
    define: {
      __BUILD_ID__: JSON.stringify(`build-${buildNumber}`),
      // Suppress development warnings from dependencies
      'process.env.NODE_ENV': JSON.stringify(mode),
      // Suppress Lit dev mode warning
      '__LIT_DEV_MODE__': 'false',
      // Suppress Node.js module warnings
      'global': 'globalThis',
      'Buffer': 'globalThis.Buffer',
      'util': 'globalThis.util',
    },
    resolve: {
      alias: {
        // Polyfill Node.js modules for browser compatibility
        buffer: 'buffer',
        util: 'util',
        process: 'process',
      },
    },
    optimizeDeps: {
      include: ['buffer', 'util', 'process'],
      esbuildOptions: {
        // Suppress Node.js module warnings
        define: {
          global: 'globalThis',
          Buffer: 'globalThis.Buffer',
          util: 'globalThis.util'
        }
      }
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom'],
            wagmi: ['wagmi', '@tanstack/react-query'],
            rainbowkit: ['@rainbow-me/rainbowkit'],
          },
        },
      },
    },
  }
})
```

### Environment Variables (`.env.local`)
```bash
# WalletConnect Project ID
VITE_WALLETCONNECT_PROJECT_ID=your_project_id_here

# Alchemy API Key (required for production)
VITE_ALCHEMY_API_KEY=your_alchemy_key_here

# Chain ID (e.g., 11155111 for Sepolia)
# Note: Uses VITE_APP_CHAIN_ID, not VITE_CHAIN_ID
VITE_APP_CHAIN_ID=11155111

# Contract addresses (update after deployment)
VITE_MY_TOKEN_ADDRESS=0x...
```

---

## ⚡ Smart Contract Development

### Hardhat Setup
```bash
# Install storage layout plugin
pnpm add -D hardhat-storage-layout

npx hardhat init
# Choose "Create a JavaScript project" (CommonJS)
# Choose "y" for .gitignore
# Choose "y" for installing dependencies
```

### Hardhat Configuration (`hardhat.config.cjs`)
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-storage-layout");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    sepolia: {
      url: process.env.SEPOLIA_URL || "https://sepolia.infura.io/v3/your-project-id",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  storageLayout: {
    outputDirectory: "./storage-layouts",
    flat: false,
  },
};
```

**Note**: This project uses CommonJS format (`.cjs`) and includes the `hardhat-storage-layout` plugin for upgradeable contract safety. Contract verification uses Sourcify and Blockscout (no Etherscan API key required).

### Example Contract (`contracts/MyToken.sol`)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

### Deployment Script (`scripts/deploy.ts`)
```typescript
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const MyToken = await ethers.getContractFactory("MyToken");
  const myToken = await MyToken.deploy();
  await myToken.waitForDeployment();

  const address = await myToken.getAddress();
  console.log("MyToken deployed to:", address);

  // Save contract address for frontend
  const fs = require('fs');
  const contractInfo = {
    address: address,
    abi: JSON.parse(myToken.interface.format('json') as string)
  };
  
  fs.writeFileSync(
    './src/contracts/MyToken.json',
    JSON.stringify(contractInfo, null, 2)
  );
  
  console.log("Contract ABI saved to src/contracts/MyToken.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

---

## 🎨 Frontend Development

### Chain Configuration (`src/config/chain.ts`)
```typescript
import { sepolia } from 'wagmi/chains'
import type { Chain } from 'wagmi/chains'

const SUPPORTED_CHAINS = [sepolia] as const
const DEFAULT_ID = sepolia.id

// Get environment variable, handle undefined gracefully
const envChainId = import.meta.env.VITE_APP_CHAIN_ID
const parsed = envChainId ? Number(envChainId) : NaN
const ENV_ID = Number.isFinite(parsed) ? parsed : DEFAULT_ID

export const APP_CHAIN_ID = SUPPORTED_CHAINS.some(c => c.id === ENV_ID) ? ENV_ID : DEFAULT_ID
export const APP_CHAIN: Chain = SUPPORTED_CHAINS.find(c => c.id === APP_CHAIN_ID)! // safe after guard
export const APP_CHAIN_NAME = APP_CHAIN.name
```

### Provider Configuration (`src/config/providers.ts`)
```typescript
/**
 * Centralized provider configuration
 * Single source of truth for all Alchemy URLs and API keys
 */

// Normalize environment variables (handle empty strings)
const normalize = (v: string | undefined) => (v && v.trim() !== '' ? v : undefined);

// Get API key from environment or fallback
const ALCHEMY_KEY = normalize(import.meta.env.VITE_ALCHEMY_API_KEY) ?? null;

// Dev-only demo key (never use in production)
const DEMO_KEY = 'A-rEh2wueYzUAbkJNHNO0h4BrtjXsH07';

// Fail fast in production if no key is provided
if (!ALCHEMY_KEY) {
  if (import.meta.env.DEV) {
    console.warn('[providers] Missing VITE_ALCHEMY_API_KEY — using demo key (dev only).');
  } else {
    console.error('[providers] Missing VITE_ALCHEMY_API_KEY in production build.');
  }
}

import { APP_CHAIN } from './chain'

export const ALCHEMY_API_KEY = ALCHEMY_KEY ?? DEMO_KEY;

// Derive all URLs from the same API key using chain configuration
export const ALCHEMY_HTTP_SEPOLIA = `https://eth-${APP_CHAIN.name.toLowerCase()}.g.alchemy.com/v2/${ALCHEMY_API_KEY}`;
export const ALCHEMY_WS_SEPOLIA = `wss://eth-${APP_CHAIN.name.toLowerCase()}.g.alchemy.com/v2/${ALCHEMY_API_KEY}`;

// Log configuration for debugging
if (import.meta.env.DEV) {
  console.log('[providers] Alchemy configuration:', {
    apiKey: ALCHEMY_API_KEY.substring(0, 10) + '...',
    httpUrl: ALCHEMY_HTTP_SEPOLIA,
    wsUrl: ALCHEMY_WS_SEPOLIA,
    isDemoKey: ALCHEMY_API_KEY === DEMO_KEY,
  });
}
```

### Wagmi Configuration (`src/config/wagmi.ts`)
```typescript
import { http, webSocket } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { ALCHEMY_HTTP_SEPOLIA, ALCHEMY_WS_SEPOLIA } from './providers'

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '4d3c5df35132e75d28a59024047bdf51'

if (!projectId) {
  console.warn('VITE_WALLETCONNECT_PROJECT_ID not found, using fallback')
}

// Mobile detection for performance tuning
const isMobile = typeof window !== 'undefined' && /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

// Build transport with Alchemy primary (SEPOLIA ONLY)
function buildSepoliaTransport() {
  console.log('🚀 Using Alchemy Sepolia as RPC provider')
  console.log('🔌 WebSocket URL:', ALCHEMY_WS_SEPOLIA)
  console.log('🌐 HTTP URL:', ALCHEMY_HTTP_SEPOLIA)
  console.log('📱 Mobile device:', isMobile ? 'Yes' : 'No')
  
  if (isMobile) {
    // Mobile: HTTP for reliable polling
    console.log('📱 Mobile detected: HTTP transport for reliable polling')
    return http(ALCHEMY_HTTP_SEPOLIA)
  } else {
    // Desktop: WebSocket ONLY - NO HTTP to prevent eth_getFilterChanges traffic
    console.log('🖥️ Desktop detected: WebSocket-ONLY transport (NO HTTP)')
    return webSocket(ALCHEMY_WS_SEPOLIA)
  }
}

// Use RainbowKit's default config with SEPOLIA ONLY transports
export const config = getDefaultConfig({
  appName: 'DamirOS DApp',
  projectId,
  chains: [sepolia], // SEPOLIA ONLY
  transports: {
    [sepolia.id]: buildSepoliaTransport(),
  },
  // Note: Polling is now handled at the hook level with explicit poll: true for mobile
  // Global pollingInterval removed to allow true WebSocket subscriptions on desktop
})
```

**Key Points**:
- Uses `getDefaultConfig` from RainbowKit (not `createConfig` from Wagmi)
- Centralized provider configuration via `providers.ts`
- Chain-based URL derivation for flexibility
- Mobile detection for transport selection (HTTP for mobile, WebSocket for desktop)

### TanStack Query Setup (`src/main.tsx`)
```typescript
// Polyfill Node.js modules for browser compatibility
import { Buffer } from 'buffer'
import * as util from 'util'

// Set global polyfills
if (typeof window !== 'undefined') {
  (window as any).Buffer = Buffer
  ;(window as any).util = util
  ;(window as any).global = window
}

import ReactDOM from 'react-dom/client'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { RainbowKitProvider } from '@rainbow-me/rainbowkit'
import { config } from './config/wagmi'
import App from './App'
import './index.css'
import '@rainbow-me/rainbowkit/styles.css'

// Create QueryClient with anti-flicker configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Prevent UI flicker by keeping previous data while refetching
      placeholderData: (previousData: any) => previousData,
      // Don't refetch on window focus to prevent unnecessary updates
      refetchOnWindowFocus: false,
      // Fail faster to prevent long loading states
      retry: 1,
      // Keep data fresh for 30 seconds to prevent redundant requests
      staleTime: 30_000,
      // Keep unused data in cache for 5 minutes
      gcTime: 5 * 60 * 1000,
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <WagmiProvider config={config}>
    <QueryClientProvider client={queryClient}>
      <RainbowKitProvider>
        <App />
        
        {/* React Query Devtools */}
        <ReactQueryDevtools initialIsOpen={false} />

      </RainbowKitProvider>
    </QueryClientProvider>
  </WagmiProvider>
)
```

### Scopes Configuration (`src/lib/scopes.ts`)
```typescript
import { QueryClient } from '@tanstack/react-query'

// Centralized scope key names to avoid typos/mismatch
export const scopes = {
  // STABLE PAGE KEYS: These don't change when count changes
  orgPage: (chainId: number, page: number, size: number) =>
    ['orgs', 'page', chainId, page, size] as const,
  
  // PARTNER-SPECIFIC KEYS: For precise invalidation
  partnersByOrg: (chainId: number, addr: string) =>
    ['orgs', 'partners', chainId, addr.toLowerCase()] as const,
  
  orgData: (chainId: number, addr: string) =>
    ['orgs', 'data', chainId, addr.toLowerCase()] as const,
  
  // BATCH KEYS: For home page partner counts
  orgPartnersPage: (chainId: number, page: number, size: number) =>
    ['orgs', 'partnersPage', chainId, page, size] as const,
  
  // UMBRELLA KEYS: For group invalidation without wildcards
  orgPartnersPageAll: (chainId: number) =>
    ['orgs', 'partnersPage', chainId] as const,
  
  orgPageAll: (chainId: number) =>
    ['orgs', 'page', chainId] as const,
  
  // CORE KEYS
  orgCount: (chainId: number) => 
    ['orgs', 'count', chainId] as const,
  
  // Legacy scopes (kept for backward compatibility)
  orgMetadata: (chainId: number, i: number) => `orgMetadata:${chainId}:${i}`,
  orgAddresses: (chainId: number, indices: string) => `orgAddresses:${chainId}:${indices}`,
  orgBatch: (chainId: number, type: string, pattern: string) => `orgBatch:${chainId}:${type}:${pattern}`,
  partners: (chainId: number, orgAddress: string) => `partners:${chainId}:${orgAddress}`,
  hasSigned: (chainId: number, orgAddress: string, userAddress: string) => `hasSigned:${chainId}:${orgAddress}:${userAddress}`,
} as const

// Debounced invalidation to prevent flicker from rapid consecutive invalidations
const pendingInvalidations = new Set<string>()
let invalidationTimeout: number | null = null

export function invalidateByScope(qc: QueryClient, scope: string | readonly unknown[]) {
  // Convert array scope to string for storage
  const scopeKey = Array.isArray(scope) ? scope.map(String).join('|') : scope
  
  // Add to pending invalidations
  pendingInvalidations.add(scopeKey as string)
  
  // Clear existing timeout
  if (invalidationTimeout) {
    clearTimeout(invalidationTimeout)
  }
  
  // Set new timeout for debounced invalidation
  invalidationTimeout = window.setTimeout(() => {
    const scopesToInvalidate = Array.from(pendingInvalidations)
    pendingInvalidations.clear()
    
    scopesToInvalidate.forEach(scopeStr => {
      // Handle array-based keys properly
      if (scopeStr.includes('|')) {
        // This is an array key, split and use for precise invalidation
        const keyParts = scopeStr.split('|')
        qc.invalidateQueries({ 
          queryKey: keyParts,
          exact: true 
        })
      } else {
        // Legacy string key, use predicate for backward compatibility
        qc.invalidateQueries({
          predicate: (q) => {
            const k = q.queryKey as unknown[]
            return Array.isArray(k) && k.some((el) => el === scopeStr)
          },
        })
      }
    })
    
    console.log(`📱 Debounced invalidation completed for scopes:`, scopesToInvalidate)
  }, 50) // 50ms debounce
}

// Precise invalidation methods using array keys
export function invalidatePartnersByOrg(qc: QueryClient, chainId: number, orgAddress: string) {
  qc.invalidateQueries({ 
    queryKey: scopes.partnersByOrg(chainId, orgAddress),
    exact: true 
  })
}

export function invalidateOrgData(qc: QueryClient, chainId: number, orgAddress: string) {
  qc.invalidateQueries({ 
    queryKey: scopes.orgData(chainId, orgAddress),
    exact: true 
  })
}

export function invalidateAllPartnerPages(qc: QueryClient, chainId: number) {
  qc.invalidateQueries({ 
    queryKey: scopes.orgPartnersPageAll(chainId),
    exact: false 
  })
}

export function invalidateOrgCount(qc: QueryClient, chainId: number) {
  qc.invalidateQueries({ 
    queryKey: scopes.orgCount(chainId),
    exact: true 
  })
}
```

---

## 🎯 Best Practices

### Hook Conflicts & Common Footguns

#### The Short Answer
- **Wagmi/Viem** = blockchain I/O (reads/writes, wallet/chain status, event watching)
- **TanStack Query** = server-state cache + fetching lifecycle (staleTime, retries, dedupe)
- **React `useState/useEffect`** = local UI state and non-data side-effects only

#### ✅ Safe Patterns

1. **Fetch data via hooks, not `useEffect`:**
   ```typescript
   const { data, isLoading, error } = useReadContract({
     address: contractAddress,
     abi: contractABI,
     functionName: 'balanceOf',
     args: [address!],
     query: {
       enabled: !!address && !!chainId,
       staleTime: 30_000,
       scopeKey: scopes.userData(chainId!, address!),
     },
   })
   ```

2. **Single source of truth:**
   - Chain/wallet status → Wagmi (`useAccount`, `useChainId`)
   - Remote data → TanStack/Wagmi read hooks (do **not** copy to `useState`)
   - Ephemeral UI (open/close, input text) → `useState`/Zustand only

3. **Guard fetches with `enabled`:**
   ```typescript
   const { address } = useAccount();
   const { data } = useReadContract({
     address: contract,
     abi,
     functionName: 'balanceOf',
     args: [address!],
     query: { enabled: !!address, staleTime: 30_000, gcTime: 300_000 }
   });
   ```

4. **Invalidate, don't setState:**
   ```typescript
   const qc = useQueryClient();
   const write = useWriteContract({
     mutation: {
       onSuccess() {
         qc.invalidateQueries({ queryKey: ['org','data', chainId, orgAddress] });
       }
     }
   });
   ```

5. **Event-driven freshness:**
   ```typescript
   useWatchContractEvent({
     address: orgAddress,
     abi,
     eventName: 'NameUpdated',
     onLogs: () => qc.invalidateQueries({ queryKey: ['org','data', chainId, orgAddress] }),
   });
   ```

#### ❌ Common Footguns to Avoid

- Fetching with `useEffect` + `fetch`/Viem while **also** using TanStack/Wagmi hooks → duplicate requests, race conditions
- Storing query results in `useState` "to pass down" → stale UI and double sources of truth
- Building `args`/`contracts` inline (new object each render) → constant refetches
- Updating UI after writes with manual `setState` instead of invalidation → cache and UI drift apart
- Mixing `refetchInterval` and event watchers without coordination → chattiness

---

## 🔌 Advanced Patterns

### Real-Time Event System

For production DApps, you need real-time event watching to update the UI when blockchain events occur. This requires a separate WebSocket client that never falls back to HTTP polling.

#### WebSocket Client (`src/realtime/wsClient.ts`)
```typescript
import { createPublicClient, webSocket } from 'viem'
import { APP_CHAIN } from '../config/chain'
import { ALCHEMY_WS_SEPOLIA } from '../config/providers'

// Create a WebSocket-only client for event watching
// This client will NEVER fall back to HTTP polling
export const wsClient = createPublicClient({
  chain: APP_CHAIN,
  transport: webSocket(ALCHEMY_WS_SEPOLIA),
})
```

#### Global Event Hook (`src/realtime/useGlobalOrgEvents.ts`)
```typescript
import { useEffect, useMemo, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { wsClient } from './wsClient'
import { APP_CHAIN_ID } from '../config/chain'
import { scopes } from '../lib/scopes'

type Addr = `0x${string}`

export function useGlobalOrgEvents(watchOrgAddresses: Addr[]) {
  const qc = useQueryClient()
  const unsubsRef = useRef<(() => void)[]>([])
  const lastBlockRef = useRef<bigint | undefined>(undefined)

  // Stable "key" so effects don't churn on large arrays
  const addrKey = useMemo(() => 
    watchOrgAddresses.map(a => a.toLowerCase()).sort().join(','), 
    [watchOrgAddresses]
  )

  useEffect(() => {
    // Set up event watchers
    async function setup() {
      // Clear existing watchers
      unsubsRef.current.forEach(u => {
        try { u() } catch {}
      })
      unsubsRef.current = []

      // Watch factory events (e.g., OrganizationDeployed)
      unsubsRef.current.push(
        wsClient.watchContractEvent({
          address: FACTORY_ADDRESS,
          abi: FACTORY_ABI,
          eventName: 'OrganizationDeployed',
          strict: false,
          poll: false, // WebSocket-only, no HTTP polling
          onLogs: (logs) => {
            // Invalidate organization count and list queries
            qc.invalidateQueries({ 
              queryKey: scopes.orgCount(APP_CHAIN_ID),
              exact: true 
            })
            qc.invalidateQueries({ 
              queryKey: scopes.orgPageAll(APP_CHAIN_ID),
              exact: false 
            })
          },
        })
      )

      // Watch per-organization events (e.g., ConstitutionSigned)
      if (watchOrgAddresses.length > 0) {
        unsubsRef.current.push(
          wsClient.watchContractEvent({
            address: watchOrgAddresses,
            abi: ORGANIZATION_ABI,
            eventName: 'ConstitutionSigned',
            strict: true,
            poll: false, // WebSocket-only
            onLogs: (logs) => {
              // Invalidate partner counts for affected organizations
              const touched = new Set<string>()
              for (const l of logs) {
                const org = (l.address as `0x${string}`).toLowerCase()
                if (!touched.has(org)) {
                  touched.add(org)
                  qc.invalidateQueries({ 
                    queryKey: scopes.partnersByOrg(APP_CHAIN_ID, org),
                    exact: true 
                  })
                }
              }
            },
          })
        )
      }
    }

    setup()

    return () => {
      // Cleanup on unmount
      unsubsRef.current.forEach(u => {
        try { u() } catch {}
      })
      unsubsRef.current = []
    }
  }, [addrKey, qc])
}
```

**Usage**: Mount once at app root:
```typescript
// In App.tsx
const { data: organizations } = usePaginatedOrganizations(0, 1000)
const orgAddresses = organizations?.map(org => org.address) || []
useGlobalOrgEvents(orgAddresses) // Watch all organizations
```

**Key Points**:
- Separate WebSocket client prevents HTTP polling fallback
- Event-driven cache invalidation keeps UI in sync
- Handles large address arrays efficiently
- Automatic cleanup on unmount

### Transaction Overlay System

For production-grade UX, implement transaction overlays that provide clear feedback during blockchain operations. This is **required** for good user experience.

**Reference Documentation**:
- Full guide: `docs/OVERLAY_SYSTEM_DOCUMENTATION.md`
- Quick reference: `docs/OVERLAY_QUICK_REFERENCE.md`

#### Modal Store (`src/stores/modalStore.ts`)
```typescript
import { create } from 'zustand'

type ModalType = 'createOrganization' | 'constitutionSigning' | null

interface ModalState {
  current: ModalType
  payload?: Record<string, unknown>
  open: (type: ModalType, payload?: Record<string, unknown>) => void
  close: () => void
}

export const useModalStore = create<ModalState>((set) => ({
  current: null,
  payload: undefined,
  open: (type, payload) => set({ current: type, payload }),
  close: () => set({ current: null, payload: undefined }),
}))
```

#### Transaction Overlay Component (`src/components/ui/TransactionOverlay.tsx`)
```typescript
interface TransactionOverlayProps {
  isVisible: boolean
  type: 'pending' | 'confirming'
  theme?: 'blue' | 'green'
  title?: string
  message?: string
}

export function TransactionOverlay({ 
  isVisible, 
  type, 
  theme = 'blue',
  title,
  message 
}: TransactionOverlayProps) {
  if (!isVisible) return null

  const defaultTitles = {
    pending: 'Waiting for Signature',
    confirming: 'Processing Transaction'
  }

  const defaultMessages = {
    pending: 'Please confirm the transaction in your wallet. Check your mobile wallet if connected there.',
    confirming: 'Your transaction is being processed on the blockchain. Please wait...'
  }

  return (
    <div className="absolute inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-8 shadow-2xl border border-gray-200 max-w-md mx-4">
        <div className="text-center space-y-4">
          <div className="w-16 h-16 bg-blue-100 border-blue-600 rounded-full flex items-center justify-center mx-auto">
            <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">
              {title || defaultTitles[type]}
            </h3>
            <p className="text-gray-600">
              {message || defaultMessages[type]}
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
```

#### Integration with Wagmi Hooks
```typescript
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { TransactionOverlay } from './components/ui/TransactionOverlay'

function MyComponent() {
  const { writeContract, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const handleTransaction = async () => {
    writeContract({
      address: CONTRACT_ADDRESS,
      abi: CONTRACT_ABI,
      functionName: 'myFunction',
      args: [],
    })
  }

  return (
    <div className="relative">
      <button onClick={handleTransaction} disabled={isPending || isConfirming}>
        Submit Transaction
      </button>

      {/* Transaction Processing Overlay */}
      {(isPending || isConfirming) && (
        <TransactionOverlay
          isVisible={true}
          type={isPending ? 'pending' : 'confirming'}
        />
      )}

      {/* Success handling */}
      {isSuccess && (
        <div>Transaction successful!</div>
      )}
    </div>
  )
}
```

**Key Points**:
- Use `isPending` for wallet signature state
- Use `isConfirming` for blockchain processing state
- Prevent user interaction during transactions
- Show clear, actionable messages
- Reference full documentation for complete implementation

### Connection Health Monitoring

For production reliability, implement connection health monitoring:

```typescript
// src/hooks/useConnectionHealth.ts
interface ConnectionHealth {
  isHealthy: boolean
  connectionQuality: 'excellent' | 'good' | 'poor' | 'failed'
  consecutiveFailures: number
  lastError?: string
}

export function useConnectionHealth() {
  // Health check via getBlockNumber()
  // Track response time and consecutive failures
  // Update connection quality based on metrics
  // Exponential backoff for reconnection
}
```

**Key Points**:
- Periodic health checks (e.g., every 2 minutes)
- Response time tracking
- Connection quality levels (excellent/good/poor/failed)
- Automatic reconnection with exponential backoff

---

## 🚀 Deployment

### Development Commands
```bash
# Install dependencies
pnpm install

# Start development server (includes build versioning)
pnpm dev

# Build for production (includes build versioning)
pnpm build

# Preview production build
pnpm preview

# Run linting
pnpm lint

# Smart contract development
pnpm compile          # Compile contracts
pnpm test            # Run contract tests
pnpm deploy:local    # Deploy to local Hardhat network
pnpm deploy:sepolia  # Deploy to Sepolia testnet
```

**Note**: Build scripts automatically run `scripts/update-version.js` to increment build counter. The `postinstall` script runs `scripts/install-hooks.js` to set up git hooks.

### Complete Development Cycle
```bash
# 1. Start local Hardhat network
npx hardhat node

# 2. In another terminal, deploy contracts locally
pnpm deploy:local

# 3. Start frontend development server
pnpm dev

# 4. Test your DApp with local contracts
# Frontend will connect to http://localhost:8545
```

### Testing on Sepolia
```bash
# 1. Deploy to Sepolia testnet
pnpm deploy:sepolia

# 2. Update your .env.local with the new contract address
VITE_MY_TOKEN_ADDRESS=0x...

# 3. Verify contract (Sourcify first, then Blockscout)
# No API keys required - use Sourcify API or Blockscout verification
# See contract verification documentation for details

# 4. Test your DApp on Sepolia
```

### Static Hosting Deployment

This DApp is designed for **static hosting** (SPA). Deploy the `dist/` folder to any static host:

**Required for SPA Routing**:
- Include a `_redirects` file in `public/` that redirects all routes to `index.html`:
  ```
  /*    /index.html   200
  ```
- This allows BrowserRouter (HTML5 history API) to work on static hosts
- Hosts like Fleek, Vercel, Netlify support this pattern

**Deployment Targets**:
- **Fleek** (IPFS-based hosting)
- **Vercel** (supports `_redirects` or `vercel.json`)
- **Netlify** (supports `_redirects` or `netlify.toml`)
- **IPFS** (manual upload to your own IPFS node)

**Environment Variables**:
- Ensure `VITE_ALCHEMY_API_KEY` is set in production
- Build will fail if missing (enforced in `vite.config.ts`)

---

## 🚨 Troubleshooting

### Common Issues

1. **Hook Conflicts**: Use Wagmi for blockchain data, TanStack Query for caching, Zustand for UI state only
2. **Stale Data**: Use proper scope keys and event-based invalidation
3. **Network Issues**: Always check `isConnected` and `chainId` before making calls
4. **Performance**: Use `enabled` guards and memoize inputs
5. **Real-time Updates**: Use separate WebSocket client (`wsClient`) for event watching to prevent HTTP polling
6. **Build Errors**: Ensure `VITE_ALCHEMY_API_KEY` is set in production builds
7. **Mobile WebSocket Issues**: Use HTTP transport for mobile devices (automatic via mobile detection)
8. **SPA Routing**: Ensure `_redirects` file is included in build output for static hosting

### Best Practices Checklist

- [ ] **Single Source of Truth**: Use Wagmi for blockchain data, TanStack Query for caching, Zustand for UI state only
- [ ] **Scope Keys**: Centralized in `scopes.ts` for consistent invalidation
- [ ] **Enabled Guards**: All hooks have proper `enabled` conditions
- [ ] **Memoized Inputs**: Use `useMemo` for objects/arrays passed to hooks
- [ ] **Event-Driven Updates**: Use separate WebSocket client for real-time event watching
- [ ] **Proper Invalidation**: Invalidate specific scopes after transactions
- [ ] **Transaction Overlays**: Implement overlays for pending/confirming states
- [ ] **Connection Health**: Monitor RPC connection health and implement reconnection
- [ ] **Error Handling**: Proper error states and loading states
- [ ] **TypeScript**: Strict typing throughout
- [ ] **Performance**: Debounced invalidations, proper staleTime/gcTime
- [ ] **Build Versioning**: Build counter system for debugging and support
- [ ] **Mobile Optimization**: Use HTTP transport for mobile devices
- [ ] **SPA Routing**: Include `_redirects` file for static hosting

---

## 📚 Additional Resources

- [Wagmi Documentation](https://wagmi.sh/)
- [Viem Documentation](https://viem.sh/)
- [TanStack Query Documentation](https://tanstack.com/query)
- [Hardhat Documentation](https://hardhat.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

---

This guide provides everything you need to build production-ready DApps with modern tooling and best practices. Follow the patterns outlined here to avoid common pitfalls and build maintainable, performant applications.
