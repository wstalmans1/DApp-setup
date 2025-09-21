# DApp Setup

A simple script to bootstrap a complete DApp development environment with React frontend and Hardhat smart contracts.

## Quick Start

1. **Create a new empty folder** for your DApp project
2. **Copy `setup.sh`** into that folder
3. **Execute the setup script**:
   ```bash
   bash setup.sh
   ```
4. **Follow the instructions** displayed after the script completes

## What You Get

- **React + TypeScript** frontend with Vite
- **Web3 integration** with Wagmi, Viem, and RainbowKit
- **Hardhat** smart contract development environment
- **Tailwind CSS** for styling
- **Monorepo structure** with pnpm workspace
- **Pre-configured** for multiple networks (Ethereum, Polygon, Optimism, Arbitrum, Sepolia)

## Next Steps

After running the script, you'll need to:

1. Edit `apps/dao-dapp/.env.local` - Set your WalletConnect ID and RPC URLs
2. Edit `packages/contracts/.env.hardhat.local` - Set your deployer key and RPC URLs
3. Run `pnpm contracts:compile` - Compile your smart contracts
4. Run `pnpm web:dev` - Start the development server

## Requirements

- Node.js 22 LTS (recommended)
- Internet access

That's it! Your DApp development environment is ready to go.
