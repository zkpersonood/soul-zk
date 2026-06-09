const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Soulbound ZK Token System...\n");

  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance:  ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);

  // ── 1. Deploy ClaimVerifier ──
  const VK_HASH = ethers.keccak256(ethers.toUtf8Bytes("soul-zk-circuit-v1"));
  const ClaimVerifier = await ethers.getContractFactory("ClaimVerifier");
  const verifier = await ClaimVerifier.deploy(VK_HASH);
  await verifier.waitForDeployment();
  console.log(`ClaimVerifier  deployed at: ${await verifier.getAddress()}`);

  // ── 2. Deploy SoulRegistry ──
  // Temporarily deploy registry with a placeholder; we'll update after SoulZK
  const SoulRegistry = await ethers.getContractFactory("SoulRegistry");
  const registry = await SoulRegistry.deploy(deployer.address); // temp, updated later
  await registry.waitForDeployment();
  console.log(`SoulRegistry   deployed at: ${await registry.getAddress()}`);

  // ── 3. Deploy SoulZK ──
  const SoulZK = await ethers.getContractFactory("SoulZK");
  const soulZK = await SoulZK.deploy(deployer.address);
  await soulZK.waitForDeployment();
  console.log(`SoulZK         deployed at: ${await soulZK.getAddress()}`);

  // ── 4. Wire up registry ──
  await registry.setSoulZK(await soulZK.getAddress());
  console.log("SoulRegistry linked to SoulZK.\n");

  // ── 5. Register a schema ──
  const schemaId = ethers.keccak256(ethers.toUtf8Bytes("identity-basic"));
  await registry.registerSchema(schemaId, "Basic Identity Verification");
  console.log(`Schema registered: ${schemaId}\n`);

  // ── Summary ──
  console.log("=== Deployment Summary ===");
  console.log(`ClaimVerifier : ${await verifier.getAddress()}`);
  console.log(`SoulRegistry  : ${await registry.getAddress()}`);
  console.log(`SoulZK        : ${await soulZK.getAddress()}`);
  console.log(`Owner         : ${deployer.address}`);
  console.log(`VK Hash       : ${VK_HASH}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
