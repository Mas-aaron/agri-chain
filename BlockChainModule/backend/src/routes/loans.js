const express = require('express');
const ContractService = require('../services/contract');
const { validateLoanData, validateRepaymentData } = require('../middleware/validators');

const router = express.Router();

/**
 * POST /api/loans
 * Create a new collateralized loan
 */
router.post('/', validateLoanData, async (req, res) => {
  try {
    const { farmerId, tokenId, loanAmountEth } = req.body;

    console.log('📥 Loan creation request:', req.body);

    const result = await ContractService.createLoan({
      farmerId,
      tokenId,
      loanAmountEth
    });

    res.status(201).json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error creating loan:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/loans
 * List all loans (with optional filters)
 */
router.get('/', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const { status = 'active', limit = 50, offset = 0 } = req.query;

    let query = 'SELECT * FROM loans';
    const params = [];

    if (status) {
      query += ' WHERE status = ?';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const loans = await DatabaseService.all(query, params);

    res.json({
      success: true,
      data: loans,
      pagination: { limit: parseInt(limit), offset: parseInt(offset) }
    });
  } catch (error) {
    console.error('Error listing loans:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/loans/:loanId
 * Get loan details
 */
router.get('/:loanId', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const loan = await DatabaseService.get(
      'SELECT * FROM loans WHERE id = ?',
      [req.params.loanId]
    );

    if (!loan) {
      return res.status(404).json({
        success: false,
        error: 'Loan not found'
      });
    }

    res.json({
      success: true,
      data: loan
    });
  } catch (error) {
    console.error('Error getting loan:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/loans/farmer/:farmerId
 * Get all loans for a farmer
 */
router.get('/farmer/:farmerId', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const loans = await DatabaseService.all(
      'SELECT * FROM loans WHERE farmer_id = ? ORDER BY created_at DESC',
      [req.params.farmerId]
    );

    res.json({
      success: true,
      data: loans
    });
  } catch (error) {
    console.error('Error getting farmer loans:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/loans/:loanId/repay
 * Repay a loan
 */
router.post('/:loanId/repay', validateRepaymentData, async (req, res) => {
  try {
    const { repaymentAmount } = req.body;

    console.log('📥 Repayment request:', { loanId: req.params.loanId, repaymentAmount });

    const result = await ContractService.repayLoan(
      req.params.loanId,
      repaymentAmount
    );

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error processing repayment:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/loans/:loanId/repayment-schedule
 * Get loan repayment details
 */
router.get('/:loanId/repayment-schedule', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const loan = await DatabaseService.get(
      'SELECT * FROM loans WHERE id = ?',
      [req.params.loanId]
    );

    if (!loan) {
      return res.status(404).json({
        success: false,
        error: 'Loan not found'
      });
    }

    const remaining = Math.max(0, loan.total_repayment - loan.repaid_amount);
    const dueDate = new Date(loan.due_date);
    const daysRemaining = Math.ceil((dueDate - new Date()) / (1000 * 60 * 60 * 24));

    res.json({
      success: true,
      data: {
        loanId: loan.id,
        principal: loan.principal_amount,
        interestRate: loan.interest_rate + '%',
        totalRepayment: loan.total_repayment,
        repaidAmount: loan.repaid_amount,
        remaining: remaining.toFixed(2),
        dueDate: dueDate.toISOString(),
        daysRemaining: Math.max(0, daysRemaining),
        status: loan.status,
        isOverdue: daysRemaining < 0
      }
    });
  } catch (error) {
    console.error('Error getting repayment schedule:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/loans/stats
 * Get loan statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const DatabaseService = require('../services/database');
    const stats = await DatabaseService.get(
      `SELECT 
        COUNT(*) as total_loans,
        COUNT(CASE WHEN status = 'active' THEN 1 END) as active_loans,
        COUNT(CASE WHEN status = 'repaid' THEN 1 END) as repaid_loans,
        COUNT(CASE WHEN status = 'liquidated' THEN 1 END) as liquidated_loans,
        SUM(principal_amount) as total_principal,
        AVG(interest_rate) as avg_interest_rate
       FROM loans`
    );

    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('Error getting loan statistics:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
