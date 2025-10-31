# Rewardy Coin Factory (Aptos Move)

This repository contains the official guide for the Aptos Move module **`rewardy_coin_factory_address::coin_factory`**.  
It defines the **Rewardy (RWD)** token using the Aptos `fungible_asset` standard and includes full lifecycle management: minting, burning, deposit/withdraw dispatching, pausing, and ownership transfer.  
The module also registers **dispatchable functions** for standardized deposit and withdrawal via `dispatchable_fungible_asset`.

> **Summary**
> - **Token Symbol:** `RWD`  
> - **Token Name:** `Rewardy`  
> - **Decimals:** `8`  
> - **Initial Supply:** `3_000_000_000_000_000_000 (u128)` 
> - **Metadata:** Includes icon URL and website URL  
> - **Owner:** Only the **root object owner (deployer address)** can perform sensitive actions such as mint, burn, pause, and ownership transfer

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [Error Codes](#error-codes)
- [Public Functions](#public-functions)
- [Deployment & Initialization](#deployment--initialization)
- [CLI Usage Examples](#cli-usage-examples)
- [Security & Permission Model](#security--permission-model)
- [License](#license)

---

## Architecture Overview

```
flowchart TD
    A[Module Deployer (rewardy_coin_factory_address)] -->|init_module| B[Create Named Object (ASSET_SYMBOL)]
    B --> C[primary_fungible_store::create_primary_store_enabled_fungible_asset]
    C --> D[Metadata Object (icon/url/decimals)]
    C --> E[MintRef / BurnRef / TransferRef / ExtendRef generation]
    E --> F[Store RewardyCoin resource (key)]
    F --> G[Initialize paused=false]
    B --> H[dispatchable_fungible_asset::register_dispatch_functions (deposit/withdraw)]
    subgraph Runtime
      I[User Primary Store] <--> |deposit/withdraw| J[FungibleAsset]
    end
```

- The **RewardyCoin resource** holds the refs (`mint_ref`, `burn_ref`, `transfer_ref`, `extend_ref`) and the `paused` flag.  
- **Ownership verification** ensures only the root object owner (module deployer) can perform admin actions.  
- When `paused == true`, all mint/burn/deposit/withdraw paths are restricted.

---

## Key Features

- ✅ Standard **Fungible Asset** creation compliant with Aptos FA framework  
- ✅ Owner-only **minting** and **burning**  
- ✅ Dispatchable **deposit/withdraw** via registered entry functions  
- ✅ **Pause/Unpause** functionality for risk control  
- ✅ **Ownership transfer** support  
- ✅ Rich **metadata** (token icon & project website)

---

## Error Codes

| Code | Constant | Description |
|------:|-----------|-------------|
| `1` | `E_NOT_OWNER` | Caller is not the root owner |
| `2` | `E_PAUSED` | Operation blocked while paused |
| `3` | `E_SAME_VALUE` | Trying to set the same value (e.g., paused → paused) |

---

## Public Functions

> **Note:** There is a typo in the function name `set_puased` in the source code — it should be `set_paused`.  
> Use the existing on-chain name if already deployed.

### View Functions
- `public fun coin_address(): address`  
  Returns the **Fungible Asset (FA)** metadata object address.

### Entry / Internal Functions
- `fun init_module(sender: &signer)`  
  Initializes the module — creates the FA, metadata, and registers dispatch functions.  
  Must be executed **only by the module deployer**.

- `public entry fun set_puased(owner: &signer, paused: bool)` *(typo preserved)*  
  Toggles pause status. Reverts if attempting to set the same value.

- `public entry fun mint(owner: &signer, to: address, amount: u64)`  
  Mints new RWD tokens and deposits them into the recipient’s primary store.

- `public entry fun burn(owner: &signer, from: address, amount: u64)`  
  Burns tokens from the specified user’s primary store.

- `public fun deposit<T: key>(store: Object<T>, fa: FungibleAsset, transfer_ref: &TransferRef)`  
  Performs a deposit using TransferRef (restricted when paused).

- `public fun withdraw<T: key>(store: Object<T>, amount: u64, transfer_ref: &TransferRef): FungibleAsset`  
  Performs a withdrawal using TransferRef (restricted when paused).

- `public entry fun change_owner(owner: &signer, new_owner: address)`  
  Transfers the **root ownership** of the FA object to a new address.

### Internal Utility Functions
- `inline fun not_paused()` → Ensures operations cannot run if paused  
- `inline fun authorized_borrow_refs(owner, asset)` → Verifies owner permissions and borrows the RewardyCoin resource

---

## Deployment & Initialization

### 1) Check constants
- Named address: `rewardy_coin_factory_address`
- Constants:
  - `ASSET_SYMBOL = "RWD"`
  - `ASSET_NAME = "Rewardy"`
  - `decimals = 8`
  - Icon and website URLs are embedded in the code — modify as needed before deployment.

### 2) Build the module
```bash
aptos move compile --named-addresses rewardy_coin_factory_address=0x<YOUR_ADDR>
```

### 3) Publish the module
```bash
aptos move publish \
  --named-addresses rewardy_coin_factory_address=0x<YOUR_ADDR> \
  --assume-yes
```

### 4) Initialize the FA object
Run `init_module` using the deployer’s signer:
```bash
aptos move run \
  --function 0x<YOUR_ADDR>::coin_factory::init_module \
  --assume-yes
```

After this step, the Rewardy FA object and metadata will be created, and dispatch functions registered.

---

## CLI Usage Examples

Let `<M>` represent your module address (`rewardy_coin_factory_address`).

### View token address
```bash
aptos move view \
  --function 0x<M>::coin_factory::coin_address
```

### Toggle paused state
```bash
# Enable pause
aptos move run \
  --function 0x<M>::coin_factory::set_puased \
  --args bool:true

# Disable pause
aptos move run \
  --function 0x<M>::coin_factory::set_puased \
  --args bool:false
```

### Mint (owner only)
```bash
aptos move run \
  --function 0x<M>::coin_factory::mint \
  --args address:0x<TO_ADDR> u64:1000000
```

### Burn (owner only)
```bash
aptos move run \
  --function 0x<M>::coin_factory::burn \
  --args address:0x<FROM_ADDR> u64:500000
```

### Deposit/Withdraw dispatchable functions
Registered under `dispatchable_fungible_asset`, these follow the standard FA dispatch pattern.

> For normal users, token transfers occur between primary stores.  
> The dispatch functions are intended for **ref-based** contract-level control.

### Transfer ownership
```bash
aptos move run \
  --function 0x<M>::coin_factory::change_owner \
  --args address:0x<NEW_OWNER>
```

---

## Security & Permission Model

- Only the **root object owner** can perform:
  - `init_module`, `set_puased`, `mint`, `burn`, `change_owner`
- When `paused == true`, the following are **restricted**:
  - `mint`, `burn`, `deposit`, `withdraw`
- `authorized_borrow_refs` ensures the signer matches the root owner via `object::root_owner(asset)`.
- Verify URLs, symbol, and decimals before deployment as they are hardcoded.

---

## License

Specify your repository license here. Example:

```
SPDX-License-Identifier: MIT
```

