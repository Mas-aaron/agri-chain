const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AgriYieldToken", function () {
  let agriToken;
  let owner, farmer1, farmer2, other;
  const baseURI = "ipfs://QmTest/";

  beforeEach(async function () {
    [owner, farmer1, farmer2, other] = await ethers.getSigners();

    const AgriYieldToken = await ethers.getContractFactory("AgriYieldToken");
    agriToken = await AgriYieldToken.deploy(baseURI);
    await agriToken.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct base URI", async function () {
      const uri = await agriToken.uri(1);
      expect(uri).to.include("ipfs");
    });

    it("Should grant MINTER_ROLE to owner", async function () {
      const minterRole = await agriToken.MINTER_ROLE();
      expect(await agriToken.hasRole(minterRole, owner.address)).to.be.true;
    });
  });

  describe("Token Minting", function () {
    it("Should mint a new yield token", async function () {
      const tx = await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-001",
        "geo123",
        "Rice",
        2024,
        1000, // predictedYield
        85,   // confidence
        "ipfs://data"
      );

      const receipt = await tx.wait();
      
      expect(tx).to.emit(agriToken, "YieldTokenMinted");
      
      const balance = await agriToken.balanceOf(farmer1.address, 1);
      expect(balance).to.equal(1000);
    });

    it("Should revert if predicted yield is 0", async function () {
      await expect(
        agriToken.mintYieldToken(
          farmer1.address,
          "FARM-001",
          "geo123",
          "Rice",
          2024,
          0, // invalid yield
          85,
          "ipfs://data"
        )
      ).to.be.revertedWith("Predicted yield must be greater than 0");
    });

    it("Should revert if confidence > 100", async function () {
      await expect(
        agriToken.mintYieldToken(
          farmer1.address,
          "FARM-001",
          "geo123",
          "Rice",
          2024,
          1000,
          101, // invalid confidence
          "ipfs://data"
        )
      ).to.be.revertedWith("Confidence must be 0-100");
    });

    it("Should retrieve yield asset details", async function () {
      await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-001",
        "geo123",
        "Rice",
        2024,
        1000,
        85,
        "ipfs://data"
      );

      const asset = await agriToken.getYieldAsset(1);
      expect(asset.farmer).to.equal(farmer1.address);
      expect(asset.farmId).to.equal("FARM-001");
      expect(asset.cropType).to.equal("Rice");
      expect(asset.predictedYield).to.equal(1000);
      expect(asset.predictionConfidence).to.equal(85);
    });
  });

  describe("Yield Updates", function () {
    beforeEach(async function () {
      await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-001",
        "geo123",
        "Rice",
        2024,
        1000,
        85,
        "ipfs://data"
      );
    });

    it("Should update actual yield after harvest", async function () {
      const oracleRole = await agriToken.ORACLE_ROLE();
      await agriToken.grantRole(oracleRole, other.address);

      const actualYield = 950;
      await agriToken.connect(other).updateActualYield(1, actualYield);

      const asset = await agriToken.getYieldAsset(1);
      expect(asset.isHarvested).to.be.true;
      expect(asset.actualYield).to.equal(actualYield);
    });

    it("Should not allow double harvesting", async function () {
      const oracleRole = await agriToken.ORACLE_ROLE();
      await agriToken.grantRole(oracleRole, other.address);

      await agriToken.connect(other).updateActualYield(1, 950);

      await expect(
        agriToken.connect(other).updateActualYield(1, 900)
      ).to.be.revertedWith("Already harvested");
    });

    it("Should calculate prediction accuracy", async function () {
      const oracleRole = await agriToken.ORACLE_ROLE();
      await agriToken.grantRole(oracleRole, other.address);

      // 95% of predicted (950/1000)
      await agriToken.connect(other).updateActualYield(1, 950);
      
      const accuracy = await agriToken.getPredictionAccuracy(1);
      expect(accuracy).to.equal(95);
    });

    it("Should return 100% for over-prediction", async function () {
      const oracleRole = await agriToken.ORACLE_ROLE();
      await agriToken.grantRole(oracleRole, other.address);

      // Actual exceeds predicted
      await agriToken.connect(other).updateActualYield(1, 1100);
      
      const accuracy = await agriToken.getPredictionAccuracy(1);
      expect(accuracy).to.equal(100);
    });
  });

  describe("Batch Transfer", function () {
    beforeEach(async function () {
      await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-001",
        "geo123",
        "Rice",
        2024,
        1000,
        85,
        "ipfs://data"
      );

      await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-002",
        "geo124",
        "Wheat",
        2024,
        500,
        80,
        "ipfs://data2"
      );
    });

    it("Should perform batch transfer", async function () {
      const ids = [1, 2];
      const amounts = [100, 50];

      await agriToken
        .connect(farmer1)
        .batchTransfer(farmer1.address, farmer2.address, ids, amounts);

      expect(await agriToken.balanceOf(farmer2.address, 1)).to.equal(100);
      expect(await agriToken.balanceOf(farmer2.address, 2)).to.equal(50);
    });

    it("Should reject unauthorized batch transfer", async function () {
      const ids = [1, 2];
      const amounts = [100, 50];

      await expect(
        agriToken
          .connect(other)
          .batchTransfer(farmer1.address, farmer2.address, ids, amounts)
      ).to.be.revertedWith("Not authorized");
    });
  });

  describe("Pause Mechanism", function () {
    it("Should allow pausing by PAUSER_ROLE", async function () {
      const pauserRole = await agriToken.PAUSER_ROLE();
      await agriToken.grantRole(pauserRole, other.address);

      await agriToken.connect(other).pause();
      expect(await agriToken.paused()).to.be.true;
    });

    it("Should prevent transfers when paused", async function () {
      await agriToken.mintYieldToken(
        farmer1.address,
        "FARM-001",
        "geo123",
        "Rice",
        2024,
        1000,
        85,
        "ipfs://data"
      );

      await agriToken.pause();

      await expect(
        agriToken
          .connect(farmer1)
          .safeTransferFrom(farmer1.address, farmer2.address, 1, 100, "0x")
      ).to.be.revertedWith("Pausable: paused");
    });
  });

  describe("Access Control", function () {
    it("Should only allow MINTER_ROLE to mint", async function () {
      await expect(
        agriToken.connect(farmer1).mintYieldToken(
          farmer1.address,
          "FARM-001",
          "geo123",
          "Rice",
          2024,
          1000,
          85,
          "ipfs://data"
        )
      ).to.be.reverted;
    });

    it("Should allow granting and revoking roles", async function () {
      const minterRole = await agriToken.MINTER_ROLE();
      
      await agriToken.grantRole(minterRole, farmer1.address);
      expect(await agriToken.hasRole(minterRole, farmer1.address)).to.be.true;

      await agriToken.revokeRole(minterRole, farmer1.address);
      expect(await agriToken.hasRole(minterRole, farmer1.address)).to.be.false;
    });
  });
});
