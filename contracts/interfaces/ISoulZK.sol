// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISoulZK
 * @notice Interface for Soulbound ZK Token system
 * @dev Non-transferable ERC721-like token with ZK attestation verification
 */
interface ISoulZK {
    /* ───── Core Events ───── */

    /// @notice Emitted when a soulbound token is minted
    event SoulMinted(uint256 indexed tokenId, address indexed to, bytes32 indexed identityCommitment);

    /// @notice Emitted when a ZK attestation claim is verified and recorded
    event ClaimVerified(uint256 indexed tokenId, bytes32 indexed claimHash, bool indexed result);

    /// @notice Emitted when a credential attestation is added to a soul
    event AttestationAdded(uint256 indexed tokenId, bytes32 indexed attestationId, bytes32 indexed schema);

    /// @notice Emitted when a registry entry is updated (metadata URI)
    event RegistryUpdated(uint256 indexed tokenId, string uri);

    /* ───── Soulbound Token ───── */

    /// @notice Mint a soulbound token to an address with an identity commitment
    function mint(address to, bytes32 identityCommitment, string memory uri) external returns (uint256 tokenId);

    /// @notice Get the identity commitment for a soulbound token
    function getIdentityCommitment(uint256 tokenId) external view returns (bytes32);

    /// @notice Verify a ZK proof for a claim against a soul's identity commitment
    function verifyClaim(uint256 tokenId, bytes32 claimHash, bytes calldata proof) external returns (bool);

    /// @notice Check if a soul has already verified a specific claim
    function hasClaim(uint256 tokenId, bytes32 claimHash) external view returns (bool);

    /* ───── Attestations ───── */

    /// @notice Add an attestation to a soulbound token
    function addAttestation(uint256 tokenId, bytes32 attestationId, bytes32 schema, bytes calldata data) external;

    /// @notice Check if a soul has a specific attestation
    function hasAttestation(uint256 tokenId, bytes32 attestationId) external view returns (bool);

    /* ───── Soul Registry ───── */

    /// @notice Update the metadata URI for a soulbound token
    function updateMetadata(uint256 tokenId, string memory uri) external;

    /// @notice Get the metadata URI for a soulbound token
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice Total number of soulbound tokens minted
    function totalSupply() external view returns (uint256);

    /// @notice Owner of a soulbound token (overrides ERC721 ownerOf)
    function ownerOf(uint256 tokenId) external view returns (address);
}
