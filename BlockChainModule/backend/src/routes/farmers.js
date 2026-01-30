const express = require('express');
const WalletService = require('../services/wallet');
const { validateFarmerData } = require('../middleware/validators');

const router = express.Router();

/**
 * POST /api/farmers
 * Create a new farmer wallet
 */
router.post('/', validateFarmerData, async (req, res) => {
  try {
    const { name, email, phone, farmLocation, farmSize, cropType } = req.body;

    const result = await WalletService.createFarmerWallet({
      name,
      email,
      phone,
      farmLocation,
      farmSize,
      cropType
    });

    res.status(201).json({
      success: true,
      data: {
        farmerId: result.farmerId,
        walletAddress: result.walletAddress,
        mnemonic: result.mnemonic,
        backupPath: result.backupPath,
        message: result.message
      }
    });
  } catch (error) {
    console.error('Error creating farmer:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/farmers
 * List all farmers
 */
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    const farmers = await WalletService.listFarmers(limit, offset);

    res.json({
      success: true,
      data: farmers,
      pagination: { limit, offset }
    });
  } catch (error) {
    console.error('Error listing farmers:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/farmers/:farmerId
 * Get farmer details
 */
router.get('/:farmerId', async (req, res) => {
  try {
    const farmer = await WalletService.getFarmerDetails(req.params.farmerId);

    res.json({
      success: true,
      data: farmer
    });
  } catch (error) {
    console.error('Error getting farmer:', error);
    res.status(404).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/farmers/:farmerId/balance
 * Get farmer wallet balance
 */
router.get('/:farmerId/balance', async (req, res) => {
  try {
    const balance = await WalletService.getFarmerBalance(req.params.farmerId);

    res.json({
      success: true,
      data: {
        balance: balance,
        unit: 'ETH'
      }
    });
  } catch (error) {
    console.error('Error getting balance:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/farmers/:farmerId/fund
 * Fund farmer wallet with gas tokens
 */
router.post('/:farmerId/fund', async (req, res) => {
  try {
    const { amountEth } = req.body;

    if (!amountEth || amountEth <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid amount'
      });
    }

    const result = await WalletService.fundFarmerWallet(
      req.params.farmerId,
      amountEth
    );

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error funding wallet:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
