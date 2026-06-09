const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SoulZK", function () {
  let SoulZK, soulZK, owner, minter, user1, user2;

  beforeEach(async function () {
    [owner, minter, user1, user2] = await ethers.getSigners();

    SoulZK = await ethers.getContractFactory("SoulZK");
    soulZK = await SoulZK.deploy(minter.address);
    await soulZK.waitForDeployment();
  });

  describe("Deployment", function () {
    it("should set the owner and minter correctly", async function () {
      expect(await soulZK.owner()).to.equal(owner.address);
      expect(await soulZK.minter()).to.equal(minter.address);
    });

    it("should start with zero total supply", async function () {
      expect(await soulZK.totalSupply()).to.equal(0);
    });
  });

  describe("Minting", function () {
    it("should allow minter to mint a soulbound token", async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("user-identity-1"));
      const uri = "ipfs://QmTest";

      await expect(soulZK.connect(minter).mint(user1.address, commitment, uri))
        .to.emit(soulZK, "SoulMinted")
        .withArgs(1, user1.address, commitment);

      expect(await soulZK.totalSupply()).to.equal(1);
      expect(await soulZK.ownerOf(1)).to.equal(user1.address);
      expect(await soulZK.getIdentityCommitment(1)).to.equal(commitment);
      expect(await soulZK.tokenURI(1)).to.equal(uri);
    });

    it("should reject minting from non-minter", async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await expect(
        soulZK.connect(user1).mint(user1.address, commitment, "uri")
      ).to.be.revertedWith("SoulZK: caller is not minter");
    });

    it("should reject minting with zero address", async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("test"));
      await expect(
        soulZK.connect(minter).mint(ethers.ZeroAddress, commitment, "uri")
      ).to.be.revertedWith("SoulZK: mint to zero address");
    });

    it("should reject minting with zero identity commitment", async function () {
      await expect(
        soulZK.connect(minter).mint(user1.address, ethers.ZeroHash, "uri")
      ).to.be.revertedWith("SoulZK: invalid identity commitment");
    });
  });

  describe("Transfer Prevention", function () {
    beforeEach(async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("identity-1"));
      await soulZK.connect(minter).mint(user1.address, commitment, "uri");
    });

    it("should prevent any transfer", async function () {
      await expect(
        soulZK.connect(user1).transfer(user2.address, 1)
      ).to.be.revertedWith("SoulZK: tokens are soulbound and cannot be transferred");
    });

    it("should prevent approval", async function () {
      await expect(
        soulZK.connect(user1).approve(user2.address, 1)
      ).to.be.revertedWith("SoulZK: soulbound tokens do not support approvals");
    });
  });

  describe("ZK Claims", function () {
    beforeEach(async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("identity-1"));
      await soulZK.connect(minter).mint(user1.address, commitment, "uri");
    });

    it("should allow soul owner to verify a claim", async function () {
      const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
      const identityCommitment = await soulZK.getIdentityCommitment(1);

      // Mock proof: encode identityCommitment + claimHash as proof bytes
      const proof = ethers.concat([
        identityCommitment,
        claimHash,
        ethers.randomBytes(64), // padding
      ]);

      await expect(soulZK.connect(user1).verifyClaim(1, claimHash, proof))
        .to.emit(soulZK, "ClaimVerified")
        .withArgs(1, claimHash, true);

      expect(await soulZK.hasClaim(1, claimHash)).to.equal(true);
    });

    it("should reject empty proof", async function () {
      const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
      await expect(
        soulZK.connect(user1).verifyClaim(1, claimHash, "0x")
      ).to.emit(soulZK, "ClaimVerified")
        .withArgs(1, claimHash, false);
    });

    it("should reject double verification of the same claim", async function () {
      const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
      const identityCommitment = await soulZK.getIdentityCommitment(1);
      const proof = ethers.concat([identityCommitment, claimHash, ethers.randomBytes(64)]);

      await soulZK.connect(user1).verifyClaim(1, claimHash, proof);
      await expect(
        soulZK.connect(user1).verifyClaim(1, claimHash, proof)
      ).to.be.revertedWith("SoulZK: claim already verified");
    });

    it("should reject verification from non-owner", async function () {
      const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
      const proof = ethers.randomBytes(128);
      await expect(
        soulZK.connect(user2).verifyClaim(1, claimHash, proof)
      ).to.be.revertedWith("SoulZK: caller is not the soul owner");
    });
  });

  describe("Attestations", function () {
    beforeEach(async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("identity-1"));
      await soulZK.connect(minter).mint(user1.address, commitment, "uri");
    });

    it("should allow minter to add an attestation", async function () {
      const attId = ethers.keccak256(ethers.toUtf8Bytes("att-1"));
      const schema = ethers.keccak256(ethers.toUtf8Bytes("kyc"));

      await expect(
        soulZK.connect(minter).addAttestation(1, attId, schema, "0x01")
      ).to.emit(soulZK, "AttestationAdded")
        .withArgs(1, attId, schema);

      expect(await soulZK.hasAttestation(1, attId)).to.equal(true);
    });

    it("should reject duplicate attestation", async function () {
      const attId = ethers.keccak256(ethers.toUtf8Bytes("att-1"));
      const schema = ethers.keccak256(ethers.toUtf8Bytes("kyc"));

      await soulZK.connect(minter).addAttestation(1, attId, schema, "0x01");
      await expect(
        soulZK.connect(minter).addAttestation(1, attId, schema, "0x01")
      ).to.be.revertedWith("SoulZK: attestation already exists");
    });
  });

  describe("Metadata", function () {
    beforeEach(async function () {
      const commitment = ethers.keccak256(ethers.toUtf8Bytes("identity-1"));
      await soulZK.connect(minter).mint(user1.address, commitment, "uri1");
    });

    it("should allow soul owner to update metadata URI", async function () {
      await expect(soulZK.connect(user1).updateMetadata(1, "uri2"))
        .to.emit(soulZK, "RegistryUpdated")
        .withArgs(1, "uri2");

      expect(await soulZK.tokenURI(1)).to.equal("uri2");
    });

    it("should reject metadata update from non-owner", async function () {
      await expect(
        soulZK.connect(user2).updateMetadata(1, "uri2")
      ).to.be.revertedWith("SoulZK: caller is not the soul owner");
    });
  });
});

describe("ClaimVerifier", function () {
  let ClaimVerifier, verifier, owner;
  const VK_HASH = ethers.keccak256(ethers.toUtf8Bytes("verification-key-v1"));

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    ClaimVerifier = await ethers.getContractFactory("ClaimVerifier");
    verifier = await ClaimVerifier.deploy(VK_HASH);
    await verifier.waitForDeployment();
  });

  it("should deploy with correct VK hash", async function () {
    expect(await verifier.verifyingKeyHash()).to.equal(VK_HASH);
  });

  it("should verify a valid proof", async function () {
    const identityCommitment = ethers.keccak256(ethers.toUtf8Bytes("pub-key"));
    const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
    const nullifier = ethers.keccak256(ethers.toUtf8Bytes("nullifier-1"));

    // Mock proof: encode identityCommitment + claimHash as first 64 bytes
    const proof = ethers.concat([identityCommitment, claimHash]);

    await expect(verifier.verifyClaim(identityCommitment, claimHash, nullifier, proof))
      .to.emit(verifier, "ProofVerified")
      .withArgs(nullifier, claimHash, owner.address);

    expect(await verifier.isNullifierSpent(nullifier)).to.equal(true);
  });

  it("should reject reused nullifier", async function () {
    const identityCommitment = ethers.keccak256(ethers.toUtf8Bytes("pub-key"));
    const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
    const nullifier = ethers.keccak256(ethers.toUtf8Bytes("nullifier-1"));
    const proof = ethers.concat([identityCommitment, claimHash]);

    await verifier.verifyClaim(identityCommitment, claimHash, nullifier, proof);
    await expect(
      verifier.verifyClaim(identityCommitment, claimHash, nullifier, proof)
    ).to.be.revertedWith("ClaimVerifier: nullifier already spent");
  });

  it("should reject invalid proof (wrong commitment)", async function () {
    const identityCommitment = ethers.keccak256(ethers.toUtf8Bytes("pub-key"));
    const claimHash = ethers.keccak256(ethers.toUtf8Bytes("age>=18"));
    const nullifier = ethers.keccak256(ethers.toUtf8Bytes("nullifier-1"));

    // Wrong commitment in proof
    const wrongCommitment = ethers.keccak256(ethers.toUtf8Bytes("wrong-key"));
    const proof = ethers.concat([wrongCommitment, claimHash]);

    const tx = await verifier.verifyClaim(identityCommitment, claimHash, nullifier, proof);
    await expect(tx).to.emit(verifier, "ProofFailed");
  });
});

describe("SoulRegistry", function () {
  let SoulRegistry, registry, SoulZK, soulZK, owner, minter, user1;

  beforeEach(async function () {
    [owner, minter, user1] = await ethers.getSigners();

    SoulZK = await ethers.getContractFactory("SoulZK");
    soulZK = await SoulZK.deploy(minter.address);
    await soulZK.waitForDeployment();

    SoulRegistry = await ethers.getContractFactory("SoulRegistry");
    registry = await SoulRegistry.deploy(await soulZK.getAddress());
    await registry.waitForDeployment();
  });

  it("should register a schema", async function () {
    const schemaId = ethers.keccak256(ethers.toUtf8Bytes("kyc"));
    await expect(registry.registerSchema(schemaId, "KYC Verification"))
      .to.emit(registry, "SchemaRegistered")
      .withArgs(schemaId, "KYC Verification");

    expect(await registry.registeredSchemas(schemaId)).to.equal(true);
  });
});
