require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const logger = require('./middleware/logger');

// Routes
const farmersRouter = require('./routes/farmers');
const yieldRouter = require('./routes/yield');
const loansRouter = require('./routes/loans');
const oracleRouter = require('./routes/oracle');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// API Routes
app.use('/api/farmers', farmersRouter);
app.use('/api/yield', yieldRouter);
app.use('/api/loans', loansRouter);
app.use('/api/oracle', oracleRouter);

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log('\n' + '='.repeat(60));
  console.log('🚀 AgriTech Backend API');
  console.log('='.repeat(60));
  console.log(`✓ Server running on http://localhost:${PORT}`);
  console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`✓ Network: ${process.env.ETHEREUM_NETWORK || 'sepolia'}`);
  console.log('='.repeat(60));
  console.log('\nEndpoints:');
  console.log('  POST   /api/farmers                    - Create farmer wallet');
  console.log('  GET    /api/farmers                    - List all farmers');
  console.log('  GET    /api/farmers/:id                - Get farmer details');
  console.log('  GET    /api/farmers/:id/balance        - Get wallet balance');
  console.log('  POST   /api/farmers/:id/fund           - Fund farmer wallet');
  console.log('');
  console.log('  POST   /api/yield/mint-token           - Mint yield token (ML webhook)');
  console.log('  POST   /api/yield/oracle-update        - Submit harvest data');
  console.log('  GET    /api/yield/:tokenId             - Get token details');
  console.log('  GET    /api/yield/:tokenId/accuracy    - Get prediction accuracy');
  console.log('');
  console.log('  POST   /api/loans                      - Create loan');
  console.log('  GET    /api/loans                      - List loans');
  console.log('  GET    /api/loans/:id                  - Get loan details');
  console.log('  POST   /api/loans/:id/repay            - Repay loan');
  console.log('  GET    /api/loans/:id/repayment-schedule');
  console.log('');
  console.log('  POST   /api/oracle/harvest-update      - Oracle harvest update');
  console.log('  GET    /api/oracle/harvest/:farmId     - Get harvest history');
  console.log('  GET    /api/oracle/stats               - Oracle statistics');
  console.log('='.repeat(60) + '\n');
});

module.exports = app;
