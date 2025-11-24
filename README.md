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

## CI & deployment

- `.github/workflows/ci.yml` runs on PRs and pushes to `main`: pnpm install, frontend lint + build, Hardhat compile/test, Foundry tests, and a non-blocking Solhint pass.
- `.github/workflows/deploy-fleek.yml` triggers after CI succeeds on `main` (or manually via `workflow_dispatch`); it rebuilds `apps/dao-dapp` and ships the `dist` folder to IPFS via `FleekHQ/action-deploy@v1`.
- Add `FLEEK_API_KEY` as a GitHub secret (scoped deploy key from Fleek dashboard). No Fleek secrets are stored in the repo.
- Generate `apps/dao-dapp/.fleek.json` by running `pnpm dlx @fleekhq/fleek-cli@0.1.8 site:init` inside that folder and committing the file. Keep the publish directory set to `dist` (or adjust the workflow if you change it).

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
