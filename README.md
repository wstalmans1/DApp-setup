# DApp scaffolding spec (canonical reference)

This repo does **not** contain a DApp. It holds the **scaffolding spec** (stack, architecture, patterns) for **client-side only** decentralized applications: static frontend (SPA), no application server, wallet-based auth, deployment to static hosting. Pass [SCAFFOLDING-SPEC.md](SCAFFOLDING-SPEC.md) to a **new project’s AI** (or use it yourself) when scaffolding; the AI uses it as the single source of truth and chooses current, compatible versions at project creation time.

---

## What’s in this repo

- **[SCAFFOLDING-SPEC.md](SCAFFOLDING-SPEC.md)** — The scaffolding spec: tech stack (React, Vite, RainbowKit, wagmi, viem, Hardhat, OpenZeppelin, etc.), architecture (monorepo, overlays, real-time events), verification (Sourcify then Blockscout), and checklist. **This is the file to hand to the new project’s AI.** It defines *what* to build (version-agnostic). For *how* to implement (step-by-step, code, best practices), use implementation guides such as the DamirOS project’s revised **Complete DApp Setup Guide** and the overlay docs linked from the spec.
- **Archive/Deprecated/** — Old setup scripts (`setup.sh`, `setup_with_factory_and_other_advanced_stuff.sh`). Not maintained for versioning; use at your own risk.
- **Archive/backup/** — Older backups of setup scripts.
- **Anvil-local-blockchain-base-for-blockscout/** — Guide for local Anvil + Blockscout (optional reference).

---

## How to use it

1. **Start a new DApp project** (new repo or folder).
2. **Give the new project’s AI the spec:** Point it at this repo’s **[SCAFFOLDING-SPEC.md](SCAFFOLDING-SPEC.md)** (or paste its contents). Example: *“Scaffold this project according to SCAFFOLDING-SPEC.md; use current compatible versions.”*
3. The AI (or you) scaffolds the new project from that spec: monorepo layout, dependencies, configs, scripts, env examples. No API keys for verification (Sourcify + Blockscout only).
4. **In the new project:** Configure env (WalletConnect ID, RPC URLs, deployer key/mnemonic), run `pnpm web:dev`, `pnpm contracts:deploy`, etc. The new project’s own README can document those steps after scaffolding.

This repo stays version-agnostic; only [SCAFFOLDING-SPEC.md](SCAFFOLDING-SPEC.md) is maintained as the source of truth. When you want to adopt a new major (e.g. Wagmi 3), update that file once.

**Spec vs implementation guides:** The spec defines *what* to scaffold (stack, architecture, patterns). The DamirOS **Complete DApp Setup Guide** (revised) is an *implementation guide*: setup steps, code snippets, Wagmi/TanStack config, scopes and debounced invalidation, real-time event system (WebSocket client, global event hook), transaction overlay system, connection health, Sourcify/Blockscout verification, `_redirects` for SPA routing, build versioning. Use it after scaffolding for concrete “how” and best practices. The spec already references the DamirOS overlay docs; a scaffolded project’s docs can reference the complete setup guide similarly.
