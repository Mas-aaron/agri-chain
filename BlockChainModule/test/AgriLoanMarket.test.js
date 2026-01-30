const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AgriLoanMarket", function () {
  let yieldToken, loanMarket;
  let owner, farmer, lender, treasury, other;
  const baseURI = "ipfs://QmTest/";

  beforeEach(async function () {
    [owner, farmer, lender, treasury, other] = await ethers.getSigners();

    // Deploy token
    const AgriYieldToken = await ethers.getContractFactory("AgriYieldToken");
    yieldToken = await AgriYieldToken.deploy(baseURI);
    await yieldToken.deployed();

    // Deploy loan market
    const AgriLoanMarket = await ethers.getContractFactory("AgriLoanMarket");
    loanMarket = await AgriLoanMarket.deploy(treasury.address);
    await loanMarket.deployed();

    // Mint some tokens to farmer
    const minterRole = await yieldToken.MINTER_ROLE();
    await yieldToken.grantRole(minterRole, owner.address);

    await yieldToken.mintYieldToken(
      farmer.address,
      "FARM-001",
      "geo123",
      "Rice",
      2024,
      1000,
      85,
      "ipfs://data"
    );

    // Approve loan market to transfer tokens
    await yieldToken
      .connect(farmer)
      .setApprovalForAll(loanMarket.address, true);
  });

  describe("Loan Creation", function () {
    it("Should create a loan with tokens as collateral", async function () {
      const loanAmount = ethers.utils.parseEther("1");

      const tx = await loanMarket.connect(farmer).createLoan(
        yieldToken.address,
        1, // tokenId
        100, // tokenAmount
        7, // durationDays
        85, // confidence
        { value: loanAmount }
      );

      expect(tx).to.emit(loanMarket, "LoanCreated");

      const loan = await loanMarket.getLoan(1);
      expect(loan.farmer).to.equal(farmer.address);
      expect(loan.tokenId).to.equal(1);
      expect(loan.tokenAmount).to.equal(100);
      expect(loan.loanAmount).to.equal(loanAmount);
    });

    it("Should calculate correct interest rate based on confidence", async function () {
      // High confidence -> lower rate
      let rate = await loanMarket.getInterestRate(85);
      expect(rate).to.equal(3); // 80%+ -> 3%

      // Medium confidence
      rate = await loanMarket.getInterestRate(65);
      expect(rate).to.equal(5); // 60-79% -> 5%

      // Low confidence
      rate = await loanMarket.getInterestRate(35);
      expect(rate).to.equal(12); // <40% -> 12%
    });

    it("Should reject loan without collateral", async function () {
      await expect(
        loanMarket.connect(farmer).createLoan(
          yieldToken.address,
          1,
          0, // no collateral
          7,
          85,
          { value: ethers.utils.parseEther("1") }
        )
      ).to.be.revertedWith("Amount must be greater than 0");
    });
  });

  describe("Loan Repayment", function () {
    beforeEach(async function () {
      const loanAmount = ethers.utils.parseEther("1");
      await loanMarket.connect(farmer).createLoan(
        yieldToken.address,
        1,
        100,
        7,
        85,
        { value: loanAmount }
      );
    });

    it("Should allow farmer to repay loan", async function () {
      const repayment = await loanMarket.calculateRepayment(1);
      
      await loanMarket
        .connect(farmer)
        .repayLoan(1, { value: repayment });

      const loan = await loanMarket.getLoan(1);
      expect(loan.isRepaid).to.be.true;
      expect(loan.isActive).to.be.false;
    });

    it("Should return tokens to farmer after repayment", async function () {
      const repayment = await loanMarket.calculateRepayment(1);
      
      const balanceBefore = await yieldToken.balanceOf(farmer.address, 1);
      
      await loanMarket
        .connect(farmer)
        .repayLoan(1, { value: repayment });

      const balanceAfter = await yieldToken.balanceOf(farmer.address, 1);
      expect(balanceAfter).to.be.gt(balanceBefore);
    });

    it("Should charge interest and platform fee", async function () {
      const treasuryBalanceBefore = await ethers.provider.getBalance(
        treasury.address
      );

      const repayment = await loanMarket.calculateRepayment(1);
      
      await loanMarket
        .connect(farmer)
        .repayLoan(1, { value: repayment });

      const treasuryBalanceAfter = await ethers.provider.getBalance(
        treasury.address
      );

      // Treasury should have received some fee
      expect(treasuryBalanceAfter).to.be.gt(treasuryBalanceBefore);
    });

    it("Should reject repayment without sufficient amount", async function () {
      await expect(
        loanMarket.connect(farmer).repayLoan(1, { value: "1" })
      ).to.be.revertedWith("Insufficient repayment");
    });
  });

  describe("Loan Liquidation", function () {
    beforeEach(async function () {
      const loanAmount = ethers.utils.parseEther("1");
      await loanMarket.connect(farmer).createLoan(
        yieldToken.address,
        1,
        100,
        1, // 1 day duration
        85,
        { value: loanAmount }
      );
    });

    it("Should liquidate overdue loan", async function () {
      // Move time forward past loan end
      await ethers.provider.send("hardhat_mine", ["0x" + (86400 * 2).toString(16)]);

      await loanMarket.connect(other).liquidateLoan(1);

      const loan = await loanMarket.getLoan(1);
      expect(loan.isLiquidated).to.be.true;
      expect(loan.isActive).to.be.false;
    });

    it("Should transfer tokens to treasury on liquidation", async function () {
      // Move time forward
      await ethers.provider.send("hardhat_mine", ["0x" + (86400 * 2).toString(16)]);

      const treasuryBalanceBefore = await yieldToken.balanceOf(
        treasury.address,
        1
      );

      await loanMarket.connect(other).liquidateLoan(1);

      const treasuryBalanceAfter = await yieldToken.balanceOf(
        treasury.address,
        1
      );

      expect(treasuryBalanceAfter).to.be.gt(treasuryBalanceBefore);
    });

    it("Should reject liquidation before loan expires", async function () {
      await expect(
        loanMarket.connect(other).liquidateLoan(1)
      ).to.be.revertedWith("Loan not yet due");
    });
  });

  describe("LTV and Settings", function () {
    it("Should allow admin to change LTV", async function () {
      const adminRole = await loanMarket.ADMIN_ROLE();
      await loanMarket.grantRole(adminRole, owner.address);

      await loanMarket.setLTV(80);
      const ltv = await loanMarket.ltv();
      expect(ltv).to.equal(80);
    });

    it("Should reject invalid LTV", async function () {
      await expect(
        loanMarket.setLTV(0)
      ).to.be.revertedWith("Invalid LTV");

      await expect(
        loanMarket.setLTV(101)
      ).to.be.revertedWith("Invalid LTV");
    });

    it("Should allow changing treasury address", async function () {
      await loanMarket.setTreasury(other.address);
      expect(await loanMarket.treasury()).to.equal(other.address);
    });
  });
});
