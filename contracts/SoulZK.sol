// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ISoulZK.sol";

/**
 * @title SoulZK
 * @notice Soulbound ZK Token — a non-transferable ERC721 variant
 * @dev Tokens are bound to an address and identity commitment. They cannot be
 *      transferred after minting. ZK proofs are used to verify claims about the
 *      holder's identity without revealing any private information.
 *
 * Features:
 * - Soulbound: tokens are minted to an address and can never be transferred.
 * - ZK Claims: holders can verify zero-knowledge proofs of claims (e.g. age,
 *   nationality, membership) linked to their identity commitment.
 * - Attestations: third-party issuers can add verifiable attestations.
 * - Registry: metadata URI attached to each token for off-chain resolver data.
 */
contract SoulZK is ISoulZK {
    /* ───── State ───── */

    /// @notice Token ID -> owner address
    mapping(uint256 => address) private _owners;

    /// @notice Token ID -> identity commitment (hash of public key / nullifier)
    mapping(uint256 => bytes32) private _identityCommitments;

    /// @notice Token ID -> metadata URI
    mapping(uint256 => string) private _tokenURIs;

    /// @notice Token ID -> claim hash -> whether the claim has been verified
    mapping(uint256 => mapping(bytes32 => bool)) private _verifiedClaims;

    /// @notice Token ID -> attestation ID -> whether it exists
    mapping(uint256 => mapping(bytes32 => bool)) private _attestations;

    /// @notice Total supply counter
    uint256 private _totalSupply;

    /// @notice Token enumerator for incremental IDs
    uint256 private _nextTokenId;

    /// @notice Contract owner (deployer) — controls administrative functions
    address public owner;

    /// @notice Minter role — allowed to mint new soulbound tokens
    address public minter;

    /* ───── Modifiers ───── */

    modifier onlyOwner() {
        require(msg.sender == owner, "SoulZK: caller is not the owner");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner, "SoulZK: caller is not minter");
        _;
    }

    modifier soulExists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "SoulZK: token does not exist");
        _;
    }

    modifier onlySoulOwner(uint256 tokenId) {
        require(_owners[tokenId] == msg.sender, "SoulZK: caller is not the soul owner");
        _;
    }

    /* ───── Constructor ───── */

    constructor(address _minter) {
        require(_minter != address(0), "SoulZK: minter cannot be zero address");
        owner = msg.sender;
        minter = _minter;
        _nextTokenId = 1;
    }

    /* ───── Soulbound Token ───── */

    /// @inheritdoc ISoulZK
    function mint(address to, bytes32 identityCommitment, string memory uri) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "SoulZK: mint to zero address");
        require(identityCommitment != bytes32(0), "SoulZK: invalid identity commitment");

        tokenId = _nextTokenId;
        _nextTokenId++;

        _owners[tokenId] = to;
        _identityCommitments[tokenId] = identityCommitment;
        _tokenURIs[tokenId] = uri;
        _totalSupply++;

        emit SoulMinted(tokenId, to, identityCommitment);
        emit RegistryUpdated(tokenId, uri);
    }

    /// @inheritdoc ISoulZK
    function getIdentityCommitment(uint256 tokenId) external view soulExists(tokenId) returns (bytes32) {
        return _identityCommitments[tokenId];
    }

    /// @inheritdoc ISoulZK
    function verifyClaim(uint256 tokenId, bytes32 claimHash, bytes calldata proof) external onlySoulOwner(tokenId) returns (bool) {
        require(claimHash != bytes32(0), "SoulZK: invalid claim hash");
        require(!_verifiedClaims[tokenId][claimHash], "SoulZK: claim already verified");

        // In a production system, this would call a verifier contract that
        // validates the Groth16/PLONK proof against the identity commitment
        // and the claim hash as public inputs.
        //
        // For this reference implementation, we simulate verification:
        // - proof must be non-empty and not exceed a reasonable size
        bool result = (proof.length > 0 && proof.length <= 4096);

        if (result) {
            _verifiedClaims[tokenId][claimHash] = true;
        }

        emit ClaimVerified(tokenId, claimHash, result);
        return result;
    }

    /// @inheritdoc ISoulZK
    function hasClaim(uint256 tokenId, bytes32 claimHash) external view returns (bool) {
        return _verifiedClaims[tokenId][claimHash];
    }

    /* ───── Attestations ───── */

    /// @inheritdoc ISoulZK
    function addAttestation(uint256 tokenId, bytes32 attestationId, bytes32 schema, bytes calldata data) external onlyMinter {
        require(attestationId != bytes32(0), "SoulZK: invalid attestation ID");
        require(!_attestations[tokenId][attestationId], "SoulZK: attestation already exists");
        require(data.length > 0, "SoulZK: empty attestation data");

        _attestations[tokenId][attestationId] = true;
        emit AttestationAdded(tokenId, attestationId, schema);
    }

    /// @inheritdoc ISoulZK
    function hasAttestation(uint256 tokenId, bytes32 attestationId) external view returns (bool) {
        return _attestations[tokenId][attestationId];
    }

    /* ───── Soul Registry ───── */

    /// @inheritdoc ISoulZK
    function updateMetadata(uint256 tokenId, string memory uri) external onlySoulOwner(tokenId) {
        _tokenURIs[tokenId] = uri;
        emit RegistryUpdated(tokenId, uri);
    }

    /// @inheritdoc ISoulZK
    function tokenURI(uint256 tokenId) external view soulExists(tokenId) returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /// @inheritdoc ISoulZK
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc ISoulZK
    function ownerOf(uint256 tokenId) external view soulExists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    /* ───── Transfer Prevention ───── */

    /// @notice Revert any transfer attempt — tokens are soulbound
    function transfer(address, uint256) external pure {
        revert("SoulZK: tokens are soulbound and cannot be transferred");
    }

    /// @notice Revert any approval attempt — no approvals for soulbound tokens
    function approve(address, uint256) external pure {
        revert("SoulZK: soulbound tokens do not support approvals");
    }

    /* ───── Admin ───── */

    /// @notice Update the minter address
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "SoulZK: invalid minter address");
        minter = _minter;
    }

    /// @notice Transfer contract ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SoulZK: invalid new owner");
        owner = newOwner;
    }

    /* ───── ERC165 ───── */

    /// @notice ERC165 support
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISoulZK).interfaceId;
    }
}
