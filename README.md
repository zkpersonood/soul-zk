# Soul ZK

A privacy-preserving soulbound token (SBT) system with zero-knowledge attestations. Non-transferable tokens that represent identity, credentials, and affiliations — all verifiable without revealing sensitive data.

## Overview

Soul ZK combines **soulbound tokens** (non-transferable NFTs) with **zero-knowledge proofs** to create private, verifiable identity credentials. Unlike traditional SBTs that expose all metadata publicly, Soul ZK allows holders to prove specific attributes about their tokens without revealing the token itself.

### Key Concepts

- **Soulbound** — Tokens cannot be transferred once minted. They are permanently bound to the owner's address.
- **ZK Attestations** — Token holders can generate ZK proofs about their credentials (e.g., "I hold a token issued before date X") without revealing the token ID or specific metadata.
- **Claim-Based** — Attestations are structured as claims with schemas, issuers, and expiration.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                     SoulZK                             │
├──────────────────────────────────────────────────────┤
│ Core soulbound token — ERC721 variant                │
│ · _transfer() disabled (soulbound enforcement)       │
│ · _mint() with ZK-compatible metadata hash           │
├──────────────────────────────────────────────────────┤
│ + mintSoul(recipient, metadata, proof)               │
│ + verifyClaim(tokenId, claim, proof) → bool         │
│ + getAttestations(tokenId) → Attestation[]           │
└──────────────────────────────────────────────────────┘
            │               │
            ▼               ▼
┌────────────────────┐ ┌──────────────────────────────┐
│   ClaimVerifier    │ │       SoulRegistry           │
├────────────────────┤ ├──────────────────────────────┤
│ Verify attestation │ │ Track all tokens + metadata  │
│ proofs             │ │ Token lifecycle management   │
└────────────────────┘ └──────────────────────────────┘
```

## Contracts

| Contract | Description |
|----------|-------------|
| **SoulZK.sol** | Main ERC721 soulbound token — handles minting, attestations, and ZK claim verification |
| **ClaimVerifier.sol** | Verifies ZK attestation proofs using on-chain verification logic |
| **SoulRegistry.sol** | Registry mapping tokens to attestations — enables discovery and verification without on-chain metadata exposure |

## Features

- **Non-transferable** — Tokens are permanently soulbound to the minting address
- **Private Attestations** — Generate ZK proofs about token attributes without revealing data
- **Multiple Claims** — Each token can have multiple claims attached
- **Issuer Verification** — Claims can be verified against trusted issuers
- **Token Metadata Hashing** — Metadata stored as commitment hashes, not raw data

## Getting Started

### Installation

```bash
git clone https://github.com/zkpersonood/soul-zk.git
cd soul-zk
npm install
npx hardhat compile
npx hardhat test
```

### Usage Flow

1. Issuer mints a soulbound token to a user
2. User receives the token (permanently bound to their address)
3. Third party requests a claim proof (e.g., "is this user a member of group X?")
4. User generates a ZK proof showing they satisfy the claim
5. Verifier checks the proof on-chain via ClaimVerifier

## Deploy

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

## Potential Applications

- **Decentralized Identity** — Portable identity credentials across dApps
- **Credential Verification** — Anonymous proof of qualifications, memberships, or affiliations
- **Reputation Systems** — Non-transferable reputation with privacy
- **Access Control** — Token-gated access without revealing which token you hold

## License

MIT
