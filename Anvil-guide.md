Perfect — here’s a **beginner-friendly `README.md`** you can drop into a folder (e.g. `~/anvil-guide/README.md`). It summarizes everything you need to know to keep using **Anvil** reliably.

````markdown
# Anvil – Local Ethereum Blockchain (Foundry)

This guide explains how to install, start, and persist a local blockchain with **Anvil**.  
It is written for macOS with Foundry already installed.

---

## 1. What is Anvil?
Anvil is a **local Ethereum node** (like Ganache or Hardhat Network).  
It gives you:
- Pre-funded test accounts with ETH
- Fast block mining
- Ability to fork mainnet/testnets
- Control over time and block production

---

## 2. Starting Anvil

Run this in **Terminal** (no `sudo` needed):

```bash
anvil \
  --host 0.0.0.0 \
  --port 8545 \
  --chain-id 31337 \
  --block-time 1 \
  -m "test test test test test test test test test test test junk" \
  --state "$HOME/.anvil/shared.json"
````

**Flags explained:**

* `--host 0.0.0.0` → allows Docker containers (e.g. Blockscout) to connect
* `--port 8545` → RPC endpoint (`http://127.0.0.1:8545`)
* `--chain-id 31337` → common dev chain ID (works with wallets)
* `--block-time 1` → mines a block every 1 second
* `-m …junk` → fixed mnemonic for **deterministic accounts**
* `--state ~/.anvil/shared.json` → saves chain state between runs

Keep this Terminal window open while Anvil is running.

---

## 3. Stopping & Restarting

* Stop Anvil → `Ctrl+C` in the Terminal
* Restart with the **same command** → it will reload from `~/.anvil/shared.json`
* This preserves all blocks, transactions, contracts, balances

⚠️ If you start Anvil **without `--state`**, the chain resets each time.

---

## 4. Accounts & Keys

Anvil starts with 10 funded accounts from the mnemonic.
Each account has **10000 ETH** (fake).
To see them:

```bash
anvil --mnemonic "test test test test test test test test test test test junk" --accounts 10
```

You can import these private keys into MetaMask for testing.

---

## 5. Connecting Projects

* **Hardhat** (`hardhat.config.ts`):

```ts
networks: {
  localhost: {
    url: "http://127.0.0.1:8545",
    chainId: 31337,
  }
}
```

* **Foundry** (`foundry.toml`):

```toml
[rpc_endpoints]
anvil = "http://127.0.0.1:8545"
```

* **MetaMask**:
  Add a new network →

  * RPC: `http://127.0.0.1:8545`
  * Chain ID: `31337`
  * Currency symbol: `ETH`

---

## 6. Useful Commands

* **Version check**

  ```bash
  anvil --version
  ```

* **Fresh chain (ignore saved state)**

  ```bash
  anvil --reset
  ```

* **Fork Ethereum mainnet**

  ```bash
  anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<API_KEY>
  ```

* **Change block time**

  ```bash
  anvil --block-time 5   # 1 block every 5 seconds
  ```

---

## 7. Running in Background

To run Anvil without keeping a Terminal window open:

```bash
nohup anvil --host 0.0.0.0 --port 8545 --chain-id 31337 \
  -m "test test test test test test test test test test test junk" \
  --state "$HOME/.anvil/shared.json" > anvil.log 2>&1 &
```

* Runs in background
* Logs go to `anvil.log`
* Stop with:

  ```bash
  pkill anvil
  ```

---

## 8. Integrating a UI (Optional)

For a web UI explorer (like Ganache used to have):

* Install **Docker Desktop**
* Run **Blockscout** with the `anvil.yml` compose file
* Open `http://localhost` to view blocks, txs, contracts

---

## 9. References

* [Foundry Book](https://book.getfoundry.sh/)
* [Anvil Docs](https://book.getfoundry.sh/anvil/)
* [Blockscout Docs](https://docs.blockscout.com/)

---

Happy hacking! 🚀

```

Would you like me to also prepare the **Blockscout setup** as a second `.md` file (so you’d have `ANVIL.md` and `BLOCKSCOUT.md` side by side), or keep it all in one file?
```
