# ZeroGate Vault

> 🚧 **Work in progress.** Phase 1 is complete: the vault logic and its test suite are done, using a mock verifier. Phase 2 (real zero-knowledge verification with Noir) has not started. **Not audited. Do not use with real funds.**

A compliance-gated **ERC-4626 yield vault**. Depositors must present a zero-knowledge proof that their compliance score is above a threshold, without revealing the score itself. Proof verification is delegated to a separate verifier contract, which will be generated from a **Noir** circuit.

---

## Table of Contents

- [ZeroGate Vault](#zerogate-vault)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [How It Works](#how-it-works)
  - [Design Decisions](#design-decisions)
    - [1. Verifier behind an interface](#1-verifier-behind-an-interface)
    - [2. Every entry point is gated](#2-every-entry-point-is-gated)
    - [3. Proofs are bound to the receiver](#3-proofs-are-bound-to-the-receiver)
    - [4. Share transfers are restricted](#4-share-transfers-are-restricted)
    - [5. Exits are open](#5-exits-are-open)
  - [Current Status](#current-status)
    - [✅ Done](#-done)
    - [🔨 In Progress](#-in-progress)
    - [📋 Planned](#-planned)
  - [Project Structure](#project-structure)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Install](#install)
    - [Remapping](#remapping)
  - [Testing](#testing)
  - [Roadmap](#roadmap)
  - [Known Limitations](#known-limitations)
  - [Tech Stack](#tech-stack)
  - [Disclaimer](#disclaimer)
  - [Author](#author)

---

## Overview

Regulated DeFi has a tension: protocols may need to restrict who can participate, but users shouldn't have to publish sensitive data (such as KYC results) on-chain.

ZeroGate Vault explores one answer. The vault publicly declares a rule: *"to deposit, you must prove your compliance score is greater than 800."* The user generates a proof off-chain, and the vault checks it on-chain. The vault learns **only that the rule is satisfied**, never the score.

**What stays private:** the user's compliance score.
**What is still public:** deposit amounts, wallet addresses, and the fact that a given address passed verification.

---

## How It Works

1. The vault is deployed with a reference to a verifier contract (`IVerifier`).
2. Off-chain, the user feeds their secret score into a ZK circuit and gets a proof.
3. The user approves the vault to spend their tokens, then calls `depositWithProof(assets, receiver, proof, publicInputs)`.
4. The vault checks that the proof is bound to the `receiver` (see below).
5. The vault calls `verifier.verify(proof, publicInputs)`.
6. If it returns `true`, the receiver is added to the verified list, tokens are pulled in, and shares are minted.
7. If it returns `false`, the entire transaction reverts.

```
User ──approve──▶ Token
User ──depositWithProof(proof)──▶ Vault ──verify(proof)──▶ Verifier
                                    │
                         true ──────┴────▶ transferFrom + mint shares
                         false ─────────▶ revert
```

---

## Design Decisions

### 1. Verifier behind an interface
The vault depends only on `IVerifier`, not on any specific implementation. A `MockVerifier` is used during development and can be swapped for the Noir-generated verifier later without changing vault logic.

### 2. Every entry point is gated
ERC-4626 normally offers two ways in: `deposit` and `mint`. Gating only one would leave the other open, so both are overridden to **always revert**. The only way to obtain shares is `depositWithProof`.

### 3. Proofs are bound to the receiver
A valid proof alone isn't enough. A proof copied from the mempool could otherwise be reused by another address. The vault requires `publicInputs[0]` to equal the receiver's address, so a proof only works for the address it was made for.

### 4. Share transfers are restricted
ERC-4626 shares are ERC-20 tokens, so by default a verified user could send shares to an unverified one, who could then redeem. The vault overrides `_update` so that user-to-user transfers only succeed if the recipient is on the verified list. Minting and burning remain unrestricted.

### 5. Exits are open
`withdraw` and `redeem` don't require a proof. The money was vetted on the way in, and forcing proofs on exit could trap funds of users who later lose compliance status.

---

## Current Status

### ✅ Done
- Foundry project setup with OpenZeppelin v5
- `IVerifier`: verifier interface
- `MockVerifier`: switchable mock (returns true or false) for testing
- `ZeroGateVault`: ERC-4626 vault with proof-gated deposits
  - `deposit` and `mint` disabled
  - `depositWithProof` with receiver binding and verifier check
  - `_update` override restricting share transfers
- Tests:
  - Deposit with a valid proof succeeds
  - Deposit with an invalid proof reverts
  - Plain `deposit` reverts
  - `mint` reverts
  - Wrong-receiver test (proof-copying protection)
  - Empty `publicInputs` test
  - Share transfer tests (to unverified and to verified recipients)
  - Withdraw and redeem tests
  - Fuzz tests for deposit amounts

### 🔨 In Progress

### 📋 Planned
- **Phase 2:** learn Noir, write a `score > 800` circuit, generate the real verifier contract, swap out the mock
- **Phase 3:** hardening
  - Issuer-signed credentials, so users can't invent their own score
  - Credential expiry
  - Revocation (a verified user who later fails compliance)
  - Input validation and edge cases
- Deployment script and testnet deployment
- Gas report and invariant tests

---

## Project Structure

```
ZeroGate-Vault/
├── src/
│   ├── IVerifier.sol        # Verifier interface
│   ├── MockVerifier.sol     # Mock verifier with a pass/fail switch
│   └── ZeroGateVault.sol    # Main ERC-4626 vault
├── test/
│   ├── ZeroGateVault.t.sol  # Vault tests
│   └── mocks/
│       └── MockERC20.sol    # Fake USDC for tests
├── lib/                     # Dependencies (OpenZeppelin, forge-std)
└── foundry.toml
```

---

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Install

```bash
git clone <your-repo-url>
cd ZeroGate-Vault
forge install
forge build
```

### Remapping
Make sure `foundry.toml` contains:

```toml
remappings = ["@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"]
```

---

## Testing

```bash
forge test -vvv          # run all tests with detailed output
forge coverage           # coverage report
forge test --list        # list discovered tests
```

Tests use `MockVerifier`, whose `setShouldPass(bool)` switch lets them simulate both valid and invalid proofs.

---

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 1 | Vault, interface, mock verifier, tests | 🔨 In progress |
| 2 | Noir circuit and real verifier integration | ⏳ Not started |
| 3 | Issuer signatures, expiry, revocation, hardening | ⏳ Not started |
| 4 | Deploy script, testnet deployment, documentation | ⏳ Not started |

---

## Known Limitations

- **No real ZK verification yet.** The mock verifier accepts anything when set to `true`.
- **No trusted issuer yet.** Until Phase 3, nothing proves the score is genuine. A user could prove "I know a number above 800" about a number they invented.
- **No revocation.** Once an address is verified, it stays verified.
- **Verified status is permanent per address.** There is no way to remove an address from the list.
- **Restricted transfers.** Users can't freely move shares to a new wallet unless that wallet has been verified.
- **Privacy is partial.** Amounts and addresses are public. Only the score is hidden.
- **Unaudited.**

---

## Tech Stack

- Solidity `^0.8.24`
- [Foundry](https://book.getfoundry.sh/) (build, test, coverage)
- [OpenZeppelin Contracts v5](https://github.com/OpenZeppelin/openzeppelin-contracts) (ERC-20, ERC-4626)
- [Noir](https://noir-lang.org/) + Barretenberg (planned)

---

## Disclaimer

This is a learning project and is **not audited**. It is not intended for production use or for handling real funds.

---

## Author

**Shubham**: building in public while learning Solidity and ZK.
