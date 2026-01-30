const hre = require("hardhat");

async function main() {
  console.log("Deploying Agri-Blockchain System...\n");
  
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // 1. Deploy AgriYieldToken (ERC-1155)
  console.log("\n--- Deploying AgriYieldToken ---");
  const AgriYieldToken = await hre.ethers.getContractFactory("AgriYieldToken");
  const baseURI = "ipfs://QmYourIPFSHash/";
  const yieldToken = await AgriYieldToken.deploy(baseURI);
  await yieldToken.deployed();
  console.log("AgriYieldToken deployed to:", yieldToken.address);

  // 2. Deploy AgriAssetRegistry
  console.log("\n--- Deploying AgriAssetRegistry ---");
  const AgriAssetRegistry = await hre.ethers.getContractFactory("AgriAssetRegistry");
  const assetRegistry = await AgriAssetRegistry.deploy();
  await assetRegistry.deployed();
  console.log("AgriAssetRegistry deployed to:", assetRegistry.address);

  // 3. Deploy AgriLoanMarket
  console.log("\n--- Deploying AgriLoanMarket ---");
  const AgriLoanMarket = await hre.ethers.getContractFactory("AgriLoanMarket");
  const loanMarket = await AgriLoanMarket.deploy(deployer.address); // Treasury = deployer
  await loanMarket.deployed();
  console.log("AgriLoanMarket deployed to:", loanMarket.address);

  // Save deployment addresses
  const deploymentAddresses = {
    agriYieldToken: yieldToken.address,
    agriAssetRegistry: assetRegistry.address,
    agriLoanMarket: loanMarket.address,
    deployer: deployer.address,
    network: hre.network.name,
    timestamp: new Date().toISOString(),
  };

  console.log("\n--- Deployment Summary ---");
  console.log(JSON.stringify(deploymentAddresses, null, 2));

  // Save to file
  const fs = require("fs");
  const fileName = `deployments/deployment-${hre.network.name}-${Date.now()}.json`;
  if (!fs.existsSync("deployments")) {
    fs.mkdirSync("deployments");
  }
  fs.writeFileSync(fileName, JSON.stringify(deploymentAddresses, null, 2));
  console.log(`\nDeployment addresses saved to: ${fileName}`);

  // Verify contracts on Etherscan (if on testnet)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\nWaiting for block confirmations before verification...");
    await yieldToken.deployTransaction.wait(5);
    
    console.log("Verifying contracts on Etherscan...");
    try {
      await hre.run("verify:verify", {
        address: yieldToken.address,
        constructorArguments: [baseURI],
      });
      console.log("AgriYieldToken verified");
    } catch (error) {
      if (error.message.includes("Already Verified")) {
        console.log("AgriYieldToken already verified");
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
