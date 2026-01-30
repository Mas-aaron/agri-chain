const { ethers } = require('ethers');
const { v4: uuidv4 } = require('uuid');
const DatabaseService = require('./database');
const WalletService = require('./wallet');
const fs = require('fs');
const path = require('path');

/**
 * Smart Contract Interaction Service
 * Handles all blockchain transactions for the AgriTech contracts
 */
class ContractService {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.ETHEREUM_RPC_URL);
    
    // Load ABIs
    const contractDir = path.resolve('../contracts');
    this.yieldTokenABI = this.loadABI('AgriYieldToken');
    this.assetRegistryABI = this.loadABI('AgriAssetRegistry');
    this.loanMarketABI = this.loadABI('AgriLoanMarket');

    // Contract addresses
    this.yieldTokenAddress = process.env.AGRI_YIELD_TOKEN_ADDRESS;
    this.assetRegistryAddress = process.env.AGRI_ASSET_REGISTRY_ADDRESS;
    this.loanMarketAddress = process.env.AGRI_LOAN_MARKET_ADDRESS;
  }

  /**
   * Load contract ABI from artifact
   * @param {string} contractName - Name of contract
   * @returns {Array} - Contract ABI
   */
  loadABI(contractName) {
    try {
      const artifactPath = path.join(
        path.resolve('../contracts'),
        `artifacts/${contractName}.json`
      );
      
      if (!fs.existsSync(artifactPath)) {
        console.warn(`⚠️  ABI for ${contractName} not found at ${artifactPath}`);
        return [];
      }

      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
      return artifact.abi || artifact;
    } catch (error) {
      console.warn(`Warning: Could not load ABI for ${contractName}:`, error.message);
      return [];
    }
  }

  /**
   * Get contract instance with signer
   * @param {string} contractAddress - Contract address
   * @param {Array} abi - Contract ABI
   * @param {ethers.Wallet} wallet - Signer wallet
   * @returns {ethers.Contract} - Contract instance
   */
  getContract(contractAddress, abi, wallet) {
    return new ethers.Contract(contractAddress, abi, wallet);
  }

  /**
   * Mint yield token when ML prediction completes
   * @param {Object} predictionData - {farmerId, farmId, cropType, season, predictedYield, confidenceScore, ipfsHash}
   * @returns {Promise<Object>} - Transaction details and token ID
   */
  async mintYieldToken(predictionData) {
    try {
      console.log('🔄 Minting yield token for prediction:', predictionData);

      // Validate farmer
      const farmer = await WalletService.getFarmerDetails(predictionData.farmerId);
      if (!farmer) throw new Error('Farmer not found');

      // Get farmer wallet for transaction
      const farmerWallet = await WalletService.getFarmerWallet(predictionData.farmerId);
      const yieldContract = this.getContract(
        this.yieldTokenAddress,
        this.yieldTokenABI,
        farmerWallet
      );

      // Prepare transaction parameters
      const txParams = {
        to: farmer.wallet_address,
        farmId: predictionData.farmId,
        cropType: predictionData.cropType,
        season: predictionData.season,
        predictedYield: ethers.parseEther(predictionData.predictedYield.toString()),
        confidenceScore: predictionData.confidenceScore, // 0-100
        ipfsHash: predictionData.ipfsHash || ''
      };

      console.log('  Sending transaction:', txParams);

      // Call contract (NOTE: replace with actual function call once ABI loaded)
      // const tx = await yieldContract.mintYieldToken(...Object.values(txParams));
      
      // For now, simulate transaction
      const tx = {
        hash: '0x' + uuidv4().replace(/-/g, '').substring(0, 64),
        from: farmer.wallet_address,
        to: this.yieldTokenAddress,
        data: 'mock_mint_call'
      };

      console.log('✓ Transaction sent:', tx.hash);

      // Record in database
      const recordId = uuidv4();
      await DatabaseService.run(
        `INSERT INTO transactions (id, farmer_id, transaction_type, transaction_hash, contract_name, function_name, parameters, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          recordId,
          predictionData.farmerId,
          'MINT_TOKEN',
          tx.hash,
          'AgriYieldToken',
          'mintYieldToken',
          JSON.stringify(txParams),
          'pending'
        ]
      );

      // Record yield token
      const yieldId = uuidv4();
      await DatabaseService.run(
        `INSERT INTO yield_tokens (id, token_id, farmer_id, farm_id, crop_type, season, predicted_yield, confidence_score, transaction_hash, token_status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          yieldId,
          uuidv4(), // Will be replaced with actual token ID after confirmation
          predictionData.farmerId,
          predictionData.farmId,
          predictionData.cropType,
          predictionData.season,
          predictionData.predictedYield,
          predictionData.confidenceScore,
          tx.hash,
          'minted'
        ]
      );

      return {
        success: true,
        transactionHash: tx.hash,
        yieldTokenId: yieldId,
        message: 'Yield token minting initiated'
      };
    } catch (error) {
      console.error('Error minting yield token:', error);
      throw error;
    }
  }

  /**
   * Register asset on-chain
   * @param {Object} assetData - {farmerId, tokenId, farmId, cropVariety, farmSizeHectares, latitude, longitude}
   * @returns {Promise<Object>} - Transaction details
   */
  async registerAsset(assetData) {
    try {
      console.log('🔄 Registering asset:', assetData);

      const farmer = await WalletService.getFarmerDetails(assetData.farmerId);
      const farmerWallet = await WalletService.getFarmerWallet(assetData.farmerId);
      const registryContract = this.getContract(
        this.assetRegistryAddress,
        this.assetRegistryABI,
        farmerWallet
      );

      // Prepare parameters
      const assetParams = {
        tokenId: assetData.tokenId,
        farmId: assetData.farmId,
        cropVariety: assetData.cropVariety,
        farmSizeHectares: assetData.farmSizeHectares,
        latitude: assetData.latitude,
        longitude: assetData.longitude
      };

      // Simulate transaction
      const tx = {
        hash: '0x' + uuidv4().replace(/-/g, '').substring(0, 64)
      };

      // Record transaction
      await DatabaseService.run(
        `INSERT INTO transactions (id, farmer_id, transaction_type, transaction_hash, contract_name, function_name, parameters, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          uuidv4(),
          assetData.farmerId,
          'REGISTER_ASSET',
          tx.hash,
          'AgriAssetRegistry',
          'registerAsset',
          JSON.stringify(assetParams),
          'pending'
        ]
      );

      console.log('✓ Asset registration initiated:', tx.hash);

      return {
        success: true,
        transactionHash: tx.hash,
        message: 'Asset registration pending'
      };
    } catch (error) {
      console.error('Error registering asset:', error);
      throw error;
    }
  }

  /**
   * Create a collateralized loan
   * @param {Object} loanData - {farmerId, tokenId, loanAmountEth}
   * @returns {Promise<Object>} - Loan details and transaction
   */
  async createLoan(loanData) {
    try {
      console.log('🔄 Creating loan:', loanData);

      const farmer = await WalletService.getFarmerDetails(loanData.farmerId);
      const farmerWallet = await WalletService.getFarmerWallet(loanData.farmerId);
      const loanContract = this.getContract(
        this.loanMarketAddress,
        this.loanMarketABI,
        farmerWallet
      );

      // Get interest rate based on confidence score
      const yieldToken = await DatabaseService.get(
        'SELECT confidence_score FROM yield_tokens WHERE token_id = ?',
        [loanData.tokenId]
      );

      if (!yieldToken) throw new Error('Token not found');

      const interestRate = this.calculateInterestRate(yieldToken.confidence_score);
      const loanAmountWei = ethers.parseEther(loanData.loanAmountEth.toString());
      const totalRepayment = this.calculateRepayment(loanData.loanAmountEth, interestRate);

      // Simulate transaction
      const tx = {
        hash: '0x' + uuidv4().replace(/-/g, '').substring(0, 64)
      };

      const loanId = uuidv4();
      const dueDate = new Date();
      dueDate.setMonth(dueDate.getMonth() + 3); // 3-month loan

      // Record loan in database
      await DatabaseService.run(
        `INSERT INTO loans (id, farmer_id, token_id, principal_amount, interest_rate, total_repayment, ltv_ratio, due_date, status, transaction_hash)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          loanId,
          loanData.farmerId,
          loanData.tokenId,
          loanData.loanAmountEth,
          interestRate,
          totalRepayment,
          0.70, // 70% LTV
          dueDate.toISOString(),
          'active',
          tx.hash
        ]
      );

      console.log('✓ Loan created:', {
        loanId,
        amount: loanData.loanAmountEth,
        interestRate: interestRate + '%',
        totalRepayment: totalRepayment
      });

      return {
        success: true,
        loanId,
        transactionHash: tx.hash,
        principalAmount: loanData.loanAmountEth,
        interestRate: interestRate + '%',
        totalRepayment: totalRepayment,
        dueDate: dueDate.toISOString(),
        message: 'Loan created successfully'
      };
    } catch (error) {
      console.error('Error creating loan:', error);
      throw error;
    }
  }

  /**
   * Process harvest data from oracle
   * @param {Object} oracleData - {tokenId, actualYield, source}
   * @returns {Promise<Object>} - Updated token data
   */
  async processOracleUpdate(oracleData) {
    try {
      console.log('🔄 Processing oracle update:', oracleData);

      // Get yield token
      const yieldToken = await DatabaseService.get(
        'SELECT * FROM yield_tokens WHERE token_id = ?',
        [oracleData.tokenId]
      );

      if (!yieldToken) throw new Error('Token not found');

      // Calculate accuracy
      const accuracy = (oracleData.actualYield / yieldToken.predicted_yield) * 100;

      // Record oracle update
      const updateId = uuidv4();
      await DatabaseService.run(
        `INSERT INTO oracle_updates (id, token_id, actual_yield, source, accuracy_percentage, processed_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          updateId,
          oracleData.tokenId,
          oracleData.actualYield,
          oracleData.source,
          accuracy,
          new Date().toISOString()
        ]
      );

      // Update yield token
      await DatabaseService.run(
        'UPDATE yield_tokens SET actual_yield = ?, token_status = ? WHERE token_id = ?',
        [oracleData.actualYield, 'harvested', oracleData.tokenId]
      );

      console.log('✓ Oracle update recorded:', {
        tokenId: oracleData.tokenId,
        actualYield: oracleData.actualYield,
        accuracy: accuracy.toFixed(2) + '%'
      });

      return {
        success: true,
        tokenId: oracleData.tokenId,
        actualYield: oracleData.actualYield,
        accuracy: accuracy.toFixed(2) + '%',
        message: 'Oracle update processed'
      };
    } catch (error) {
      console.error('Error processing oracle update:', error);
      throw error;
    }
  }

  /**
   * Repay a loan
   * @param {string} loanId - Loan ID
   * @param {number} repaymentAmount - Amount to repay in ETH
   * @returns {Promise<Object>} - Repayment details
   */
  async repayLoan(loanId, repaymentAmount) {
    try {
      console.log('🔄 Processing loan repayment:', { loanId, repaymentAmount });

      const loan = await DatabaseService.get(
        'SELECT * FROM loans WHERE id = ?',
        [loanId]
      );

      if (!loan) throw new Error('Loan not found');
      if (loan.status !== 'active') throw new Error('Loan is not active');

      const farmer = await WalletService.getFarmerDetails(loan.farmer_id);
      const farmerWallet = await WalletService.getFarmerWallet(loan.farmer_id);

      // Simulate transaction
      const tx = {
        hash: '0x' + uuidv4().replace(/-/g, '').substring(0, 64)
      };

      const newRepaidAmount = loan.repaid_amount + repaymentAmount;
      const isFullyRepaid = newRepaidAmount >= loan.total_repayment;

      // Update loan status
      await DatabaseService.run(
        'UPDATE loans SET repaid_amount = ?, status = ?, repaid_at = ? WHERE id = ?',
        [
          newRepaidAmount,
          isFullyRepaid ? 'repaid' : 'active',
          isFullyRepaid ? new Date().toISOString() : null,
          loanId
        ]
      );

      console.log('✓ Loan repayment recorded:', {
        loanId,
        repaidAmount: newRepaidAmount,
        totalRepayment: loan.total_repayment,
        status: isFullyRepaid ? 'fully repaid' : 'partial'
      });

      return {
        success: true,
        loanId,
        transactionHash: tx.hash,
        repaidAmount: newRepaidAmount,
        totalRepayment: loan.total_repayment,
        remaining: Math.max(0, loan.total_repayment - newRepaidAmount),
        fullyRepaid: isFullyRepaid,
        message: isFullyRepaid ? 'Loan fully repaid' : 'Partial repayment recorded'
      };
    } catch (error) {
      console.error('Error repaying loan:', error);
      throw error;
    }
  }

  /**
   * Calculate interest rate based on confidence score
   * @param {number} confidenceScore - ML confidence (0-100)
   * @returns {number} - Interest rate (%)
   */
  calculateInterestRate(confidenceScore) {
    if (confidenceScore >= 80) return 3;
    if (confidenceScore >= 60) return 5;
    if (confidenceScore >= 40) return 8;
    return 12;
  }

  /**
   * Calculate total repayment amount
   * @param {number} principal - Principal in ETH
   * @param {number} interestRate - Annual interest rate
   * @returns {number} - Total repayment amount
   */
  calculateRepayment(principal, interestRate) {
    // 3-month loan = 0.25 year
    const interest = principal * (interestRate / 100) * 0.25;
    return principal + interest;
  }

  /**
   * Get transaction status
   * @param {string} transactionHash - Transaction hash
   * @returns {Promise<Object>} - Transaction details
   */
  async getTransactionStatus(transactionHash) {
    try {
      const tx = await this.provider.getTransaction(transactionHash);
      const receipt = await this.provider.getTransactionReceipt(transactionHash);

      return {
        hash: transactionHash,
        status: receipt ? (receipt.status === 1 ? 'success' : 'failed') : 'pending',
        blockNumber: receipt?.blockNumber,
        gasUsed: receipt?.gasUsed.toString(),
        confirmations: receipt ? await this.provider.getBlockNumber() - receipt.blockNumber : 0
      };
    } catch (error) {
      console.error('Error getting transaction status:', error);
      return { hash: transactionHash, status: 'unknown', error: error.message };
    }
  }
}

module.exports = new ContractService();
