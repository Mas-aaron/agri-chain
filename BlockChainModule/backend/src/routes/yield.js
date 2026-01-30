const express = require('express');
const ContractService = require('../services/contract');
const OracleService = require('../services/oracle');
const { validateYieldData, validateHarvestData } = require('../middleware/validators');

const router = express.Router();

/**
 * POST /api/yield/mint-token
 * Mint yield token when ML prediction completes
 * Called by ML prediction system
 */
router.post('/mint-token', validateYieldData, async (req, res) => {
  try {
    const { farmerId, farmId, cropType, season, predictedYield, confidenceScore, ipfsHash } = req.body;

    console.log('📥 Received mint request:', req.body);

    // Record prediction in oracle service
    await OracleService.receivePrediction({
      farmId,
      cropType,
      season,
      predictedYield,
      confidenceScore,
      modelVersion: req.body.modelVersion || 'v1.0'
    });

    // Mint token on blockchain
    const result = await ContractService.mintYieldToken({
      farmerId,
      farmId,
      cropType,
      season,
      predictedYield,
      confidenceScore,
      ipfsHash
    });

    res.status(201).json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error minting yield token:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/yield/oracle-update
 * Receive harvest data from oracle
 */
router.post('/oracle-update', validateHarvestData, async (req, res) => {
  try {
    const { tokenId, actualYield, farmId, harvestDate, source } = req.body;

    console.log('📥 Oracle update received:', req.body);

    // Process oracle update
    const result = await ContractService.processOracleUpdate({
      tokenId,
      actualYield,
      farmId,
      source: source || 'harvest_oracle'
    });

    // Submit to blockchain
    await OracleService.submitHarvestData({
      tokenId,
      actualYield,
      farmId,
      harvestDate
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error processing oracle update:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/yield/:tokenId
 * Get yield token details
 */
router.get('/:tokenId', async (req, res) => {
  try {
    // Query database for token
    const DatabaseService = require('../services/database');
    const token = await DatabaseService.get(
      'SELECT * FROM yield_tokens WHERE token_id = ?',
      [req.params.tokenId]
    );

    if (!token) {
      return res.status(404).json({
        success: false,
        error: 'Token not found'
      });
    }

    res.json({
      success: true,
      data: token
    });
  } catch (error) {
    console.error('Error getting yield token:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/yield/farm/:farmId
 * Get all yield tokens for a farm
 */
router.get('/farm/:farmId', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const tokens = await DatabaseService.all(
      'SELECT * FROM yield_tokens WHERE farm_id = ? ORDER BY created_at DESC',
      [req.params.farmId]
    );

    res.json({
      success: true,
      data: tokens
    });
  } catch (error) {
    console.error('Error getting farm tokens:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/yield/farmer/:farmerId
 * Get all yield tokens for a farmer
 */
router.get('/farmer/:farmerId', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const tokens = await DatabaseService.all(
      'SELECT * FROM yield_tokens WHERE farmer_id = ? ORDER BY created_at DESC',
      [req.params.farmerId]
    );

    res.json({
      success: true,
      data: tokens
    });
  } catch (error) {
    console.error('Error getting farmer yield tokens:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/yield/:tokenId/accuracy
 * Get token prediction accuracy
 */
router.get('/:tokenId/accuracy', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const update = await DatabaseService.get(
      'SELECT accuracy_percentage, actual_yield FROM oracle_updates WHERE token_id = ? ORDER BY processed_at DESC LIMIT 1',
      [req.params.tokenId]
    );

    if (!update) {
      return res.json({
        success: true,
        data: {
          accuracy: null,
          message: 'Harvest data not yet available'
        }
      });
    }

    res.json({
      success: true,
      data: {
        accuracy: update.accuracy_percentage.toFixed(2) + '%',
        actualYield: update.actual_yield
      }
    });
  } catch (error) {
    console.error('Error getting accuracy:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
