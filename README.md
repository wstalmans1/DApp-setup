# DApp setup — pointer to canonical docs

Both the **scaffolding spec** (what to build) and the **setup and implementation guide** (how to build) are centralized in one place:

**[DamirOS_dapp_rainbowkit](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit)** — that project’s documentation is the **single source of truth** for DApp scaffolding and implementation. The canonical docs are in **`docs/dapp_setup_guides/`**: [001_scaffolding_spec.md](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit/blob/main/docs/dapp_setup_guides/001_scaffolding_spec.md) (what to build) and [002_setup_instrctions_and_best_practices.md](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit/blob/main/docs/dapp_setup_guides/002_setup_instrctions_and_best_practices.md) (how to build).

Use them to scaffold new client-side DApps (stack, architecture, patterns) and to follow step-by-step setup, code, overlay system, real-time events, connection health, verification (Sourcify + Blockscout), etc.

---

## What’s in this repo

- **Pointer files** — [001_scaffolding_spec.md](001_scaffolding_spec.md) and [002_setup_instrctions_and_best_practices.md](002_setup_instrctions_and_best_practices.md) redirect to the canonical docs of the same names in **DamirOS_dapp_rainbowkit**. Do not treat this repo as the source of truth; use that project’s docs.
- **Archive/Deprecated/** — Old setup scripts (`setup.sh`, `setup_with_factory_and_other_advanced_stuff.sh`). Not maintained; use at your own risk.
- **Archive/backup/** — Older backups of setup scripts.
- **Anvil-local-blockchain-base-for-blockscout/** — Guide for local Anvil + Blockscout (optional reference).

---

## How to use it

1. **Go to [DamirOS_dapp_rainbowkit](https://github.com/wstalmans1/DamirOS_dapp_rainbowkit)** for **`001_scaffolding_spec.md`** and **`002_setup_instrctions_and_best_practices.md`**.
2. Use **`001_scaffolding_spec.md`** when bootstrapping a new project (or when handing the spec to an AI).
3. Use **`002_setup_instrctions_and_best_practices.md`** for step-by-step instructions, code, and best practices after scaffolding.

This repo does not hold the canonical spec or guide; it only points to DamirOS_dapp_rainbowkit.
