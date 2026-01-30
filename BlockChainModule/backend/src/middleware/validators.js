const Joi = require('joi');

/**
 * Validate farmer data
 */
const validateFarmerData = (req, res, next) => {
  const schema = Joi.object({
    name: Joi.string().required().min(2),
    email: Joi.string().email().required(),
    phone: Joi.string().optional(),
    farmLocation: Joi.string().required(),
    farmSize: Joi.number().positive().required(),
    cropType: Joi.string().required()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

/**
 * Validate yield token data
 */
const validateYieldData = (req, res, next) => {
  const schema = Joi.object({
    farmerId: Joi.string().required(),
    farmId: Joi.string().required(),
    cropType: Joi.string().required(),
    season: Joi.string().required(),
    predictedYield: Joi.number().positive().required(),
    confidenceScore: Joi.number().min(0).max(100).required(),
    ipfsHash: Joi.string().optional(),
    modelVersion: Joi.string().optional()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

/**
 * Validate harvest/oracle data
 */
const validateHarvestData = (req, res, next) => {
  const schema = Joi.object({
    tokenId: Joi.string().required(),
    actualYield: Joi.number().positive().required(),
    farmId: Joi.string().optional(),
    harvestDate: Joi.date().optional(),
    source: Joi.string().optional()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

/**
 * Validate loan creation data
 */
const validateLoanData = (req, res, next) => {
  const schema = Joi.object({
    farmerId: Joi.string().required(),
    tokenId: Joi.string().required(),
    loanAmountEth: Joi.number().positive().required()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

/**
 * Validate loan repayment data
 */
const validateRepaymentData = (req, res, next) => {
  const schema = Joi.object({
    repaymentAmount: Joi.number().positive().required()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

/**
 * Validate oracle update
 */
const validateOracleUpdate = (req, res, next) => {
  const schema = Joi.object({
    farmId: Joi.string().required(),
    season: Joi.string().optional(),
    actualYield: Joi.number().positive().required(),
    harvestDate: Joi.date().optional(),
    source: Joi.string().optional(),
    quality: Joi.string().optional()
  });

  const { error, value } = schema.validate(req.body);
  
  if (error) {
    return res.status(400).json({
      success: false,
      error: error.details[0].message
    });
  }

  req.body = value;
  next();
};

module.exports = {
  validateFarmerData,
  validateYieldData,
  validateHarvestData,
  validateLoanData,
  validateRepaymentData,
  validateOracleUpdate
};
