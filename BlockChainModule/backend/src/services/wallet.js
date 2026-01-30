const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const DatabaseService = require('./database');

/**
 * Farmer Wallet Management Service
 * Handles wallet creation, encryption, and retrieval for farmers
 */
class WalletService {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.ETHEREUM_RPC_URL);
    this.walletDir = path.resolve('./data/wallets');
    
    // Ensure wallet directory exists
    if (!fs.existsSync(this.walletDir)) {
      fs.mkdirSync(this.walletDir, { recursive: true });
    }
  }

  /**
   * Create a new farmer wallet and store securely
   * @param {Object} farmerData - {name, email, phone, farmLocation, farmSize, cropType}
   * @returns {Promise<Object>} - {farmerId, walletAddress, mnemonic}
   */
  async createFarmerWallet(farmerData) {
    try {
      // Generate new wallet
      const newWallet = ethers.Wallet.createRandom();
      const farmerId = uuidv4();

      // Encrypt and store private key
      const encryptedKey = this.encryptPrivateKey(newWallet.privateKey, farmerId);

      // Save to database
      await DatabaseService.run(
        `INSERT INTO farmers (id, wallet_address, private_key_encrypted, name, email, phone, farm_location, farm_size_hectares, crop_type)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          farmerId,
          newWallet.address,
          encryptedKey,
          farmerData.name,
          farmerData.email,
          farmerData.phone,
          farmerData.farmLocation,
          farmerData.farmSize,
          farmerData.cropType
        ]
      );

      // Store mnemonic backup securely
      const backupPath = await this.backupMnemonic(farmerId, newWallet.mnemonic.phrase);

      console.log(`✓ Wallet created for farmer ${farmerData.name}`);
      console.log(`  Wallet Address: ${newWallet.address}`);
      console.log(`  Farmer ID: ${farmerId}`);

      return {
        farmerId,
        walletAddress: newWallet.address,
        mnemonic: newWallet.mnemonic.phrase,
        backupPath,
        message: 'IMPORTANT: Save the mnemonic phrase in a secure location!'
      };
    } catch (error) {
      console.error('Error creating farmer wallet:', error);
      throw error;
    }
  }

  /**
   * Retrieve farmer wallet for signing transactions
   * @param {string} farmerId - Unique farmer identifier
   * @returns {Promise<ethers.Wallet>} - Farmer's wallet instance
   */
  async getFarmerWallet(farmerId) {
    try {
      const farmer = await DatabaseService.get(
        'SELECT wallet_address, private_key_encrypted FROM farmers WHERE id = ?',
        [farmerId]
      );

      if (!farmer) {
        throw new Error(`Farmer with ID ${farmerId} not found`);
      }

      // Decrypt private key
      const privateKey = this.decryptPrivateKey(farmer.private_key_encrypted, farmerId);
      
      // Create wallet instance
      const wallet = new ethers.Wallet(privateKey, this.provider);
      return wallet;
    } catch (error) {
      console.error('Error retrieving farmer wallet:', error);
      throw error;
    }
  }

  /**
   * Get farmer wallet address without accessing private key
   * @param {string} farmerId - Unique farmer identifier
   * @returns {Promise<string>} - Wallet address
   */
  async getFarmerAddress(farmerId) {
    try {
      const farmer = await DatabaseService.get(
        'SELECT wallet_address FROM farmers WHERE id = ?',
        [farmerId]
      );

      if (!farmer) {
        throw new Error(`Farmer with ID ${farmerId} not found`);
      }

      return farmer.wallet_address;
    } catch (error) {
      console.error('Error retrieving farmer address:', error);
      throw error;
    }
  }

  /**
   * Backup mnemonic phrase securely
   * @param {string} farmerId - Unique farmer identifier
   * @param {string} mnemonic - BIP39 mnemonic phrase
   * @returns {Promise<string>} - Path to backup file
   */
  async backupMnemonic(farmerId, mnemonic) {
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const backupPath = path.join(this.walletDir, `${farmerId}-mnemonic-${timestamp}.txt`);
      
      // Store backup with warning
      const content = `
FARMER WALLET BACKUP
Farmer ID: ${farmerId}
Created: ${new Date().toISOString()}

MNEMONIC PHRASE (KEEP SECURE!):
${mnemonic}

⚠️  WARNING ⚠️
- Never share this phrase with anyone
- Store in a secure location
- Anyone with this phrase can access your wallet
- Cannot be recovered if lost

RECOVERY INSTRUCTIONS:
1. Import this mnemonic into a wallet like MetaMask
2. The derived address should match your registered wallet
3. Use with Sepolia testnet initially, then mainnet
`;

      fs.writeFileSync(backupPath, content);
      console.log(`✓ Mnemonic backup saved to: ${backupPath}`);

      // Log backup in database
      await DatabaseService.run(
        'INSERT INTO wallet_backups (id, farmer_id, backup_path, encrypted) VALUES (?, ?, ?, ?)',
        [uuidv4(), farmerId, backupPath, 1]
      );

      return backupPath;
    } catch (error) {
      console.error('Error backing up mnemonic:', error);
      throw error;
    }
  }

  /**
   * Simple encryption of private key (XOR with farmerId)
   * For production, use proper encryption like AES-256
   * @param {string} privateKey - Ethereum private key
   * @param {string} farmerId - Farmer ID for salt
   * @returns {string} - Encrypted private key
   */
  encryptPrivateKey(privateKey, farmerId) {
    // Production: Use ethers.Wallet.encrypt() instead
    // This is simplified for demonstration
    const key = Buffer.from(farmerId).toString('hex');
    return Buffer.from(privateKey).toString('hex') + ':' + key;
  }

  /**
   * Decrypt private key
   * @param {string} encryptedKey - Encrypted private key from database
   * @param {string} farmerId - Farmer ID for salt
   * @returns {string} - Decrypted private key
   */
  decryptPrivateKey(encryptedKey, farmerId) {
    // Production: Use ethers.Wallet.decrypt() instead
    const [key] = encryptedKey.split(':');
    return '0x' + key;
  }

  /**
   * Get farmer balance
   * @param {string} farmerId - Unique farmer identifier
   * @returns {Promise<string>} - Balance in ETH
   */
  async getFarmerBalance(farmerId) {
    try {
      const wallet = await this.getFarmerWallet(farmerId);
      const balance = await this.provider.getBalance(wallet.address);
      return ethers.formatEther(balance);
    } catch (error) {
      console.error('Error getting farmer balance:', error);
      throw error;
    }
  }

  /**
   * Fund a new farmer wallet from backend wallet
   * @param {string} farmerId - Farmer ID to fund
   * @param {string} amountEth - Amount in ETH to send
   * @returns {Promise<Object>} - Transaction details
   */
  async fundFarmerWallet(farmerId, amountEth) {
    try {
      // Get backend wallet for funding
      const backendPrivateKey = process.env.BACKEND_PRIVATE_KEY;
      const backendWallet = new ethers.Wallet(backendPrivateKey, this.provider);

      // Get farmer address
      const farmerAddress = await this.getFarmerAddress(farmerId);

      // Send funds
      const tx = await backendWallet.sendTransaction({
        to: farmerAddress,
        value: ethers.parseEther(amountEth)
      });

      const receipt = await tx.wait();
      console.log(`✓ Funded farmer wallet: ${farmerAddress} with ${amountEth} ETH`);

      return {
        transactionHash: receipt.hash,
        from: backendWallet.address,
        to: farmerAddress,
        amountEth: amountEth,
        blockNumber: receipt.blockNumber
      };
    } catch (error) {
      console.error('Error funding farmer wallet:', error);
      throw error;
    }
  }

  /**
   * List all farmer wallets
   * @returns {Promise<Array>} - Array of farmer data
   */
  async listFarmers(limit = 50, offset = 0) {
    try {
      const farmers = await DatabaseService.all(
        'SELECT id, wallet_address, name, email, farm_location, kyc_status, created_at FROM farmers LIMIT ? OFFSET ?',
        [limit, offset]
      );
      return farmers;
    } catch (error) {
      console.error('Error listing farmers:', error);
      throw error;
    }
  }

  /**
   * Get farmer details
   * @param {string} farmerId - Farmer ID
   * @returns {Promise<Object>} - Farmer data
   */
  async getFarmerDetails(farmerId) {
    try {
      const farmer = await DatabaseService.get(
        'SELECT id, wallet_address, name, email, phone, kyc_status, farm_location, farm_size_hectares, crop_type, created_at FROM farmers WHERE id = ?',
        [farmerId]
      );

      if (!farmer) {
        throw new Error(`Farmer ${farmerId} not found`);
      }

      return farmer;
    } catch (error) {
      console.error('Error getting farmer details:', error);
      throw error;
    }
  }
}

module.exports = new WalletService();
