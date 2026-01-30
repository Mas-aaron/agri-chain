const express = require('express');
const OracleService = require('../services/oracle');
const { validateOracleUpdate } = require('../middleware/validators');

const router = express.Router();

/**
 * POST /api/oracle/harvest-update
 * Receive harvest data from oracle provider
 */
router.post('/harvest-update', validateOracleUpdate, async (req, res) => {
  try {
    const { farmId, season, actualYield, harvestDate, source, quality } = req.body;

    console.log('📥 Harvest oracle update received:', req.body);

    // Submit harvest data
    const result = await OracleService.submitHarvestData({
      farmId,
      season,
      actualYield,
      harvestDate,
      source: source || 'external_oracle'
    });

    res.json({
      success: true,
      data: result,
      message: 'Harvest data recorded and submitted to blockchain'
    });
  } catch (error) {
    console.error('Error processing oracle harvest update:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/oracle/harvest/:farmId
 * Get harvest data for a farm
 */
router.get('/harvest/:farmId', async (req, res) => {
  try {
    const history = await OracleService.getHarvestHistory(req.params.farmId);

    res.json({
      success: true,
      data: history,
      count: history.length
    });
  } catch (error) {
    console.error('Error getting harvest history:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/oracle/stats
 * Get oracle performance statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const stats = await OracleService.getOracleStats();

    if (!stats || stats.total_updates === 0) {
      return res.json({
        success: true,
        data: {
          message: 'No oracle updates yet'
        }
      });
    }

    res.json({
      success: true,
      data: {
        totalUpdates: stats.total_updates,
        averageAccuracy: stats.avg_accuracy ? stats.avg_accuracy.toFixed(2) + '%' : 'N/A',
        minAccuracy: stats.min_accuracy ? stats.min_accuracy.toFixed(2) + '%' : 'N/A',
        maxAccuracy: stats.max_accuracy ? stats.max_accuracy.toFixed(2) + '%' : 'N/A'
      }
    });
  } catch (error) {
    console.error('Error getting oracle stats:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/oracle/query/:farmId
 * Query oracle for available harvest data
 */
router.get('/query/:farmId', async (req, res) => {
  try {
    const { season } = req.query;

    if (!season) {
      return res.status(400).json({
        success: false,
        error: 'Season parameter required'
      });
    }

    const result = await OracleService.queryHarvestData(
      req.params.farmId,
      season
    );

    res.json({
      success: result.success,
      data: result.harvestData || result.mockData,
      timestamp: result.timestamp
    });
  } catch (error) {
    console.error('Error querying oracle:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
