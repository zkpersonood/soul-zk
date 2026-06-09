# Soul ZK

Soulbound tokens with zero-knowledge privacy for on-chain attestations and credentials. Non-transferable by design.

## Contracts

- **SoulZK.sol** — Main soulbound token contract (ERC721 variant, non-transferable) with ZK proof verification
- **ClaimVerifier.sol** — On-chain verifier for anonymous attestations
- **SoulRegistry.sol** — Registry of soulbound tokens and their associated attestations

## Features

- Non-transferable tokens (soulbound)
- ZK privacy for credential claims
- Attestation verification without revealing data
- Claim-based credential system

## Getting Started

```bash
npm install
npx hardhat compile
npx hardhat test
```
