# Tech Stack — DApp (canonical description)

This document is the **single source of truth** for the desired tech stack. Use it when bootstrapping a new project (or hand it to an AI): implement the stack with **current, compatible versions** at the time of scaffolding. Do not pin exact versions in long-lived scaffolding scripts; resolve versions at project creation time.

**Versioning:** Major version numbers below (e.g. "Wagmi 2", "React 18") describe the **compatible ecosystem** to target. When scaffolding, use the current stable minor/patch within that major. When a newer major is released and you want to adopt it (e.g. Wagmi 3, Vite 7), update this document once so it stays the source of truth. The doc is future-proof because you maintain intent here and resolve concrete versions at scaffold time; only the doc needs a deliberate edit when you move to a new major.

**Application scope: client-side only.** This stack is for **client-side only** decentralized applications. The app is a **static frontend** (SPA) that runs in the browser and talks to blockchains (and optionally decentralized storage such as IPFS). Do **not** scaffold an application server, server-side API routes, server-side rendering (SSR), or server-held secrets. Deployment target is static hosting (e.g. Fleek, Vercel, Netlify, IPFS). Auth is wallet-based (RainbowKit/wagmi) only. Any “backend” is the chain and, if needed, external read-only or decentralized services.

---

## 1. Frontend framework & core

- **React 18** — UI library.
- **TypeScript** — Strict mode enabled; full type coverage. Target modern ES (e.g. ES2020+).
- **Vite** — Build tool and dev server (use current stable major: 5 or 6). Output is a **static SPA** (no SSR, no server runtime).
- **React Router DOM 6** — Client-side routing only. Use **BrowserRouter** (HTML5 history API) for clean URLs (e.g. `/organization/0x123`). For this to work on static hosting (Fleek, IPFS, Vercel, Netlify), the app must include a **`_redirects`** file (or the host’s equivalent) so every path is served `index.html`; otherwise refresh or direct links to deep routes return 404. Prefer this over hash-based routing (`HashRouter`), which works without host config but gives URLs with `#`.
- **Module system**: ESM (`"type": "module"`). JSX: React JSX transform (`react-jsx`). Module resolution: bundler.

---

## 2. Blockchain & Web3

- **Wagmi 2** — React hooks for Ethereum (use current 2.x).
- **Viem 2** — TypeScript Ethereum library (use current 2.x).
- **RainbowKit 2** — Wallet connection UI (use current 2.x).
- **TanStack Query 5** — Data fetching and caching for chain/API data.
- **TanStack Query Devtools** — Dev tools (e.g. only in development).
- **WalletConnect** — Multi-wallet connection protocol (RainbowKit uses it).
- Wallet support: MetaMask, WalletConnect, Coinbase Wallet, and other WalletConnect-compatible wallets.

---

## 3. State management

- **Zustand** — Lightweight global state (use current 4.x).
- Server/chain state: TanStack Query + Wagmi; use Zustand for app-level UI/domain state.

---

## 4. Styling & UI

- **Tailwind CSS** — Utility-first CSS (Tailwind 3 or 4; if 4, use `@tailwindcss/postcss` and `@import "tailwindcss"`).
- **PostCSS** — CSS processing.
- **Autoprefixer** — Include if required by your Tailwind major (Tailwind 4 may bundle this).
- Optional: design tokens / CSS variables for theming.

---

## 5. Smart contracts development

- **Hardhat 2** — Ethereum development environment (use 2.x; avoid mixing with Hardhat 3 ESM/viem until you explicitly want that stack).
- **Hardhat Toolbox** (or equivalent) — Plugins for compilation, testing, network, etc. (e.g. `@nomicfoundation/hardhat-toolbox` with ethers v6, or toolbox-viem if you prefer viem in Hardhat).
- **Solidity 0.8.x** — Smart contract language (e.g. 0.8.22–0.8.28; use a single consistent version).
- **OpenZeppelin Contracts** — Security-audited contract libraries (current 5.x).
- **OpenZeppelin Contracts Upgradeable** — Upgradeable patterns (Initializable, UUPS/TransparentProxy, etc.).
- **OpenZeppelin Hardhat Upgrades plugin** — **Required for upgrade workflows**: `@openzeppelin/hardhat-upgrades`. Use for `deployProxy`, `upgradeProxy`, and storage layout checks. Ensure it is installed and loaded in `hardhat.config.*`.
- **Hardhat Storage Layout** (optional) — Plugin to report or export storage layout (e.g. for upgrade safety reviews). OpenZeppelin’s upgrade plugin already validates layout on upgrade; a dedicated plugin can help with documentation or CI.
- **TypeChain** — Generate TypeScript types from ABIs for frontend and scripts (e.g. `@typechain/hardhat`, `typechain`, `@typechain/ethers-v6` or viem equivalents).
- **hardhat-deploy** (optional) — Reproducible deployments, tags, and saved addresses.
- **hardhat-gas-reporter** — Gas and optional USD estimates on test runs.
- **hardhat-contract-sizer** — Bytecode size on compile (stay under 24KB limit).
- **Networks**: Hardhat network (local, e.g. chainId 1337), Sepolia testnet, Ethereum mainnet; optionally Polygon, Optimism, Arbitrum. RPC via env (user-supplied URLs). Optional: Alchemy or other provider with WebSocket for real-time events.

---

## 6. Contract upgrades (must-have)

- **OpenZeppelin Hardhat Upgrades** — `@openzeppelin/hardhat-upgrades` in the Hardhat project: used for deploying and upgrading proxies.
- **OpenZeppelin Contracts Upgradeable** — Use `Initializable`, proxy contracts (UUPS or Transparent), and follow OZ upgrade safety rules (no constructors in implementation, no new storage after base, etc.).
- **Deploy/upgrade scripts** — Scripts or tasks to: deploy implementation + proxy, upgrade existing proxy to new implementation. Reuse `upgrades.deployProxy` / `upgrades.upgradeProxy` (or equivalent).
- **Storage layout** — Rely on the OZ plugin’s checks; optionally add a storage-layout plugin or CI step that fails on unexpected layout changes.
- Optional patterns: **Beacon proxy** (one implementation, many proxies) or **factory** (deploy many instances); add if the product needs them.

---

## 7. Contract verification (Sourcify first, then Blockscout — no API key)

- **No Etherscan** — Do not use Etherscan or any verification path that requires an API key (e.g. `ETHERSCAN_API_KEY`). Use only Sourcify and Blockscout so verification works without API keys.
- **1. Sourcify (first)** — Verify on Sourcify first: submit contract metadata + sources via [Sourcify API](https://docs.sourcify.dev/docs/api/server) or use a Hardhat plugin (e.g. `@sourcify-dev/hardhat-sourcify` or equivalent). No API key required. Once Sourcify has the data, Blockscout and other Sourcify-backed explorers can show verified source automatically.
- **2. Blockscout (then)** — Also verify directly on Blockscout: use Hardhat’s verify task (or equivalent) with a custom chain pointing at Blockscout’s API (e.g. `https://eth-sepolia.blockscout.com/api` for Sepolia). Blockscout typically does not require an API key; use a placeholder if the plugin expects one. Add a “blockscout” (or per-chain) network entry with `apiURL` and `browserURL`. Run this after or in addition to Sourcify so contracts are verified on Blockscout as well.
- **Standard JSON input** — For complex or flattened builds, support verification via standard-json-input where the chosen tools allow it (e.g. Blockscout, or Sourcify submission with full metadata).
- **Upgradeable contracts** — Verification script/task for proxy + implementation: submit both to Sourcify first, then verify proxy and implementation on Blockscout as required.

---

## 8. NatSpec & contract docs

- **NatSpec in Solidity** — Use `@title`, `@author`, `@notice`, `@dev`, `@param`, `@return`, `@custom:security-contact` (and tags) on all public/external functions and contracts.
- **solidity-docgen** — Generate Markdown (or other) docs from NatSpec. Run on compile or via a dedicated task; output to e.g. `docs/`.
- **NatSpec coverage / lint** (optional) — Linter or CI step that enforces NatSpec on public APIs (e.g. fail if `@notice` is missing on public functions). Improves doc quality over time.

---

## 9. Build & bundle (frontend)

- **Code splitting** — Use Vite’s Rollup options to define **manual chunks** for better caching and load: e.g. separate chunks for `vendor` (react, react-dom, etc.), `wagmi`, `rainbowkit`, and optionally `viem`. This matches the “manual chunks for vendor, wagmi, rainbowkit” approach and improves long-term cache hits.
- **Tree shaking** — Enabled via Vite’s build optimization; use ESM imports so unused code is dropped.
- **Build output** — Production build to `dist/` (or equivalent). The app is a **SPA (single-page application)**: one HTML shell; routing is client-side (React Router). Include a **`_redirects`** file in the build output (or the static host’s equivalent, e.g. Netlify/Fleek `_redirects`, Vercel rewrites) so that every path serves `index.html`. That way BrowserRouter works on refresh and deep links; without it, history-based routing breaks on static hosts.

---

## 10. Node / browser polyfills (if needed)

- If the frontend or tooling expects Node globals in the browser (e.g. `buffer`, `process`, `util`), add the minimal polyfills required (e.g. `buffer`, `process`, `util` packages and Vite `define` or a small polyfill bundle). Many Vite setups do not need these; add only if you hit “process is not defined” or similar.
- Optional native add-ons for build performance (e.g. `bufferutil`, `utf-8-validate`, `keccak`, `secp256k1`) can be installed optionally; do not force them in the canonical stack.

---

## 11. Development tools

- **ESLint** — Linting (current flat config format preferred: `eslint.config.js`).
- **TypeScript ESLint** — Parser and plugin for TS (e.g. `@typescript-eslint/parser`, `@typescript-eslint/eslint-plugin`).
- **ESLint Plugin React Hooks** — Enforce Rules of Hooks.
- **ESLint Plugin React Refresh** (optional) — React Refresh lint rules.
- **Prettier** — Code formatting (TS/JS and, if applicable, Solidity via `prettier-plugin-solidity`).
- **Solhint** (optional) — Linting for Solidity.
- **Type definitions** — `@types/node`, `@types/react`, `@types/react-dom` (versions compatible with React 18 and your Node target).
- **Husky + lint-staged** — Pre-commit (and optionally pre-push) hooks to run lint and format so the repo stays clean.

---

## 12. Testing

- **Contract tests** — Hardhat tests (JavaScript/TypeScript) and/or **Foundry** (Forge) for fast unit and fuzz tests. Foundry is optional but recommended for speed.
- **Frontend tests** — Vitest or Jest (Vitest fits Vite well). At least one runner and a minimal setup so UI logic can be tested.
- **Local chain** — Hardhat network or **Anvil** (Foundry) for local dev; scripts to start/stop (e.g. `anvil:start` / `anvil:stop`).

---

## 13. Repo structure & tooling

- **Package manager**: **pnpm**. Use a pnpm workspace for monorepos.
- **Monorepo layout** (example): `apps/<frontend-app>/`, `packages/contracts/`. Root scripts: `web:dev`, `web:build`, `web:preview`, `contracts:compile`, `contracts:test`, `contracts:deploy`, `contracts:verify`, `contracts:verify:multi`, `contracts:verify-upgradeable`, `anvil:start`, `anvil:stop`, `check:all` (lint + build + contract tests).
- **Contract artifacts** — Compilation output (ABIs, etc.) consumed by the frontend (e.g. `apps/<app>/src/contracts/` or a shared package). TypeChain types for frontend if applicable.
- **Environment** — `.env.example` (or similar) for `VITE_*` (WalletConnect ID, RPC URLs, etc.) and for Hardhat (e.g. `PRIVATE_KEY` or `MNEMONIC`, RPC URLs). Do not require any explorer API keys; verification is via Blockscout and Sourcify only. Never commit secrets.

---

## 14. Deployment & hosting

- **Frontend** — Build output (`dist/`) deployable to any static host or CDN (e.g. Fleek, Vercel, Netlify, IPFS gateways). Use `_redirects` (or host equivalent) so all routes serve `index.html` and BrowserRouter works; avoid hash-based routing unless the host cannot be configured.
- **Optional: IPFS / decentralized** — Helia, Storacha, Pinata, Fleek SDK, or similar for content-addressed storage or deployment; add only if the product needs it.

---

## 15. Optional but recommended

- **Connection health & reconnection** — WebSocket or polling for RPC health; automatic reconnection in Wagmi/viem config.
- **Overlay system (transaction treatment)** — Provide clear, in-app feedback for blockchain transactions via **overlays** (not only toasts). Recommended pieces:
  - **Transaction overlay** — Full-screen or modal overlay with backdrop (e.g. semi-transparent + blur). Two states: **pending** (waiting for wallet signature; message like “Please confirm in your wallet”) and **confirming** (transaction submitted; “Processing on blockchain”). Use Wagmi: `useWriteContract` plus `useWaitForTransactionReceipt`; drive overlay visibility from `isPending` and `isConfirming`.
  - **Success overlay** — After confirmation, show a success state (e.g. checkmark, short message, optional “View on explorer” link). User dismisses explicitly (e.g. Close button); then reset or close the flow.
  - **Modal management** — Use Zustand (or similar) for a small modal store: which overlay/modal is open and optional payload. Render a single **ModalManager** (or overlay orchestrator) near the app root that renders the active overlay from that state.
  - **UX rules** — Disable primary actions and prevent closing the modal/overlay while `isPending` or `isConfirming`. On error, show error message and allow retry without losing context. Optional: **wallet confirmation banner** (e.g. orange/amber strip) during pending to remind users to check a mobile wallet.
  - **Structure** — e.g. `stores/modalStore.ts`, components such as `TransactionOverlay`, `SuccessOverlay`, and a root `ModalManager` that composes them. Tailwind for layout and styling (backdrop, blur, spinner, success icon). Prefer accessible markup (e.g. `role="dialog"`, `aria-labelledby`) where applicable.
  - **Reference** — Full implementation guide and code snippets: [OVERLAY_QUICK_REFERENCE.md](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit/blob/main/docs/OVERLAY_QUICK_REFERENCE.md) and [OVERLAY_SYSTEM_DOCUMENTATION.md](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit/blob/main/docs/OVERLAY_SYSTEM_DOCUMENTATION.md).
- **Mobile** — Prefer transport that works on mobile (e.g. HTTP fallback if WebSocket is flaky).
- **Build versioning** — Inject a build id or version (e.g. git SHA, env var) for support and debugging.
- **Static analysis** — Slither or similar for contracts (optional, run locally or in CI).
- **CI** — GitHub Actions (or other) to run lint, build, and contract tests on push/PR; or document that checks run locally via Husky and `check:all`.

---

## 16. Summary checklist (for scaffolding)

- [ ] **Client-side only:** Static SPA, no app server, no SSR, no server API routes; static hosting + wallet auth
- [ ] React 18 + TypeScript + Vite + React Router 6 (BrowserRouter + `_redirects` for static host so history routing works)
- [ ] Wagmi 2 + Viem 2 + RainbowKit 2
- [ ] TanStack Query 5 + Devtools + Zustand
- [ ] Tailwind + PostCSS (and Autoprefixer if needed)
- [ ] Hardhat 2 + Solidity 0.8.x + OZ Contracts + OZ Contracts Upgradeable
- [ ] **@openzeppelin/hardhat-upgrades** (contract upgrades)
- [ ] TypeChain, gas-reporter, contract-sizer; optional: hardhat-deploy, storage-layout plugin
- [ ] Verification: Sourcify first, then Blockscout (no Etherscan, no API key); standard-json and upgradeable scripts as needed
- [ ] NatSpec everywhere + solidity-docgen; optional: NatSpec lint
- [ ] Vite manual chunks (vendor, wagmi, rainbowkit)
- [ ] ESLint (flat) + Prettier + Husky + lint-staged
- [ ] pnpm workspace; scripts for web, contracts, verify, anvil, check
- [ ] Optional: Overlay system (transaction + success overlays, modal store, ModalManager, Wagmi integration)
- [ ] Optional: Foundry, IPFS/Helia, React Refresh ESLint, buffer/process polyfills

Use this document as the basis for generating a new project; choose current major/minor versions and exact package names at scaffold time.
