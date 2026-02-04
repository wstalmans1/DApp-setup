# DApp Tech Stack (canonical reference)

This repo does **not** contain a DApp. It holds the **canonical tech stack description** so you can pass it to a **new project’s AI** (or use it yourself) when scaffolding a DApp. The AI uses it as the single source of truth and chooses current, compatible versions at project creation time.

---

## What’s in this repo

- **[TECH-STACK.md](TECH-STACK.md)** — The canonical stack: frontend (React, Vite, RainbowKit, wagmi, viem, etc.), contracts (Hardhat, OpenZeppelin, upgrades), verification (Sourcify then Blockscout), NatSpec, tooling, and checklist. **This is the file to hand to the new project’s AI.**
- **Archive/Deprecated/** — Old setup scripts (`setup.sh`, `setup_with_factory_and_other_advanced_stuff.sh`). Not maintained for versioning; use at your own risk.
- **backup/** — Older backups of setup scripts.
- **Anvil-local-blockchain-base-for-blockscout/** — Guide for local Anvil + Blockscout (optional reference).

---

## How to use it

1. **Start a new DApp project** (new repo or folder).
2. **Give the new project’s AI the stack:** Point it at this repo’s **[TECH-STACK.md](TECH-STACK.md)** (or paste its contents). Example: *“Scaffold this project according to the tech stack in TECH-STACK.md; use current compatible versions.”*
3. The AI (or you) scaffolds the new project from that spec: monorepo layout, dependencies, configs, scripts, env examples. No API keys for verification (Sourcify + Blockscout only).
4. **In the new project:** Configure env (WalletConnect ID, RPC URLs, deployer key/mnemonic), run `pnpm web:dev`, `pnpm contracts:deploy`, etc. The new project’s own README can document those steps after scaffolding.

This repo stays version-agnostic; only [TECH-STACK.md](TECH-STACK.md) is maintained as the source of truth. When you want to adopt a new major (e.g. Wagmi 3), update that file once.
