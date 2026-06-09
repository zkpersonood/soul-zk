// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ISoulZK.sol";

/**
 * @title SoulRegistry
 * @notice Registry of soulbound tokens and their attestations
 * @dev Extension registry that provides aggregation and query capabilities
 *      for soulbound tokens. Maintains a reverse lookup (address -> tokens)
 *      and attestation records. Works alongside the main SoulZK contract.
 */
contract SoulRegistry {
    /* ───── State ───── */

    /// @notice Address of the main SoulZK token contract
    address public soulZK;

    /// @notice Contract owner
    address public owner;

    /// @notice Token ID -> timestamp of first attestation/mint
    mapping(uint256 => uint256) public soulCreation;

    /// @notice Token ID -> array of attestation IDs
    mapping(uint256 => bytes32[]) public soulAttestations;

    /// @notice Token ID -> attestation ID -> attestation data hash
    mapping(uint256 => mapping(bytes32 => bytes32)) public attestationData;

    /// @notice Schema ID -> whether it's registered
    mapping(bytes32 => bool) public registeredSchemas;

    /// @notice address -> tokens[] (reverse lookup)
    mapping(address => uint256[]) private _holderTokens;

    /* ───── Events ───── */

    event SoulRegistered(uint256 indexed tokenId, address indexed holder, uint256 timestamp);
    event SchemaRegistered(bytes32 indexed schemaId, string description);
    event AttestationRecorded(uint256 indexed tokenId, bytes32 indexed attestationId, bytes32 indexed schema, bytes32 dataHash);
    event AttestationRevoked(uint256 indexed tokenId, bytes32 indexed attestationId);

    /* ───── Modifiers ───── */

    modifier onlyOwner() {
        require(msg.sender == owner, "SoulRegistry: not owner");
        _;
    }

    modifier onlySoulZK() {
        require(msg.sender == soulZK, "SoulRegistry: only SoulZK can call");
        _;
    }

    /* ───── Constructor ───── */

    constructor(address _soulZK) {
        require(_soulZK != address(0), "SoulRegistry: invalid SoulZK address");
        owner = msg.sender;
        soulZK = _soulZK;
    }

    /* ───── Registration ───── */

    /**
     * @notice Register a newly minted soulbound token in the registry
     * @dev Called by SoulZK after minting
     */
    function registerSoul(uint256 tokenId, address holder) external onlySoulZK {
        require(soulCreation[tokenId] == 0, "SoulRegistry: soul already registered");

        soulCreation[tokenId] = block.timestamp;
        _holderTokens[holder].push(tokenId);

        emit SoulRegistered(tokenId, holder, block.timestamp);
    }

    /* ───── Schema Registration ───── */

    /**
     * @notice Register an attestation schema
     * @param schemaId Unique identifier for the schema (e.g., keccak256("age-verification"))
     * @param description Human-readable description
     */
    function registerSchema(bytes32 schemaId, string calldata description) external onlyOwner {
        require(!registeredSchemas[schemaId], "SoulRegistry: schema already registered");
        registeredSchemas[schemaId] = true;
        emit SchemaRegistered(schemaId, description);
    }

    /* ───── Attestation Management ───── */

    /**
     * @notice Record an attestation for a soulbound token
     * @dev Called by SoulZK when an attestation is added
     */
    function recordAttestation(
        uint256 tokenId,
        bytes32 attestationId,
        bytes32 schema,
        bytes32 dataHash
    ) external onlySoulZK {
        require(registeredSchemas[schema], "SoulRegistry: unregistered schema");
        require(attestationData[tokenId][attestationId] == bytes32(0), "SoulRegistry: attestation exists");

        attestationData[tokenId][attestationId] = dataHash;
        soulAttestations[tokenId].push(attestationId);

        emit AttestationRecorded(tokenId, attestationId, schema, dataHash);
    }

    /**
     * @notice Revoke an attestation by its ID
     */
    function revokeAttestation(uint256 tokenId, bytes32 attestationId) external onlyOwner {
        require(attestationData[tokenId][attestationId] != bytes32(0), "SoulRegistry: attestation not found");
        attestationData[tokenId][attestationId] = bytes32(0);
        emit AttestationRevoked(tokenId, attestationId);
    }

    /* ───── Query Functions ───── */

    /**
     * @notice Get all token IDs held by an address
     */
    function getTokensOf(address holder) external view returns (uint256[] memory) {
        return _holderTokens[holder];
    }

    /**
     * @notice Get the number of tokens held by an address
     */
    function balanceOf(address holder) external view returns (uint256) {
        return _holderTokens[holder].length;
    }

    /**
     * @notice Get all attestation IDs for a soul
     */
    function getAttestations(uint256 tokenId) external view returns (bytes32[] memory) {
        return soulAttestations[tokenId];
    }

    /**
     * @notice Get the creation timestamp of a soul
     */
    function getSoulAge(uint256 tokenId) external view returns (uint256) {
        require(soulCreation[tokenId] > 0, "SoulRegistry: soul not found");
        return block.timestamp - soulCreation[tokenId];
    }

    /* ───── Admin ───── */

    function setSoulZK(address _soulZK) external onlyOwner {
        require(_soulZK != address(0), "SoulRegistry: invalid address");
        soulZK = _soulZK;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SoulRegistry: invalid new owner");
        owner = newOwner;
    }
}
