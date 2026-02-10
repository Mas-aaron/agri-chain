// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title YieldDiscrepancyInsurance
 * @dev Comprehensive insurance system for agricultural yield discrepancies
 * with multi-layer risk management and ML model staking
 */
contract YieldDiscrepancyInsurance is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Insurance Tiers
    enum InsuranceTier {
        BRONZE,     // 50% coverage, 3% premium
        SILVER,     // 60% coverage, 2.5% premium
        GOLD,       // 70% coverage, 2% premium
        PLATINUM    // 80% coverage, 1.5% premium
    }

    // Policy Structure
    struct InsurancePolicy {
        uint256 policyId;
        address insured;
        uint256 tokenId;
        uint256 predictedYield;
        uint256 insuredAmount;
        uint256 premiumPaid;
        uint256 deductible;           // percentage farmer bears (basis points)
        uint256 coverageRate;         // percentage insurance covers (basis points)
        InsuranceTier tier;
        uint256 createdAt;
        uint256 expiresAt;
        bool isActive;
        bool hasClaimed;
    }

    // ML Model Staking
    struct ModelStake {
        address modelProvider;
        uint256 stakedAmount;
        uint256 accuracyScore;        // 0-1000 scale
        uint256 totalPredictions;
        uint256 lastUpdated;
        bool isActive;
    }

    // Oracle Consensus
    struct OracleReport {
        uint256 tokenId;
        uint256 predictedYield;
        uint256 actualYield;
        uint256 confidence;          // 0-1000 scale
        uint256 sourceCount;         // number of oracle sources
        uint256 reportedAt;
        bool isVerified;
    }

    // Insurance Pool
    struct InsurancePool {
        uint256 totalReserve;
        uint256 activePolicies;
        uint256 totalClaimsPaid;
        uint256 totalPremiumsCollected;
        uint256 lastReserveUpdate;
    }

    // State Variables
    mapping(uint256 => InsurancePolicy) public policies;
    mapping(address => ModelStake) public modelStakes;
    mapping(uint256 => OracleReport) public oracleReports;
    mapping(address => uint256) public policyCounter;
    
    // Insurance pools by tier
    mapping(InsuranceTier => InsurancePool) public insurancePools;
    
    // Configuration
    uint256 public minReserveRatio = 1500; // 15% in basis points
    uint256 public maxCoverageRate = 8000; // 80% in basis points
    uint256 public minDeductible = 500;     // 5% in basis points
    uint256 public claimThreshold = 500;    // 5% discrepancy threshold
    
    // Oracle addresses
    address public yieldOracle;
    address public priceOracle;
    mapping(string => address) public authorizedOracles;
    
    // Events
    event PolicyCreated(
        uint256 indexed policyId,
        address indexed insured,
        uint256 tokenId,
        uint256 coverageAmount,
        InsuranceTier tier
    );
    
    event PremiumPaid(
        uint256 indexed policyId,
        uint256 amount,
        uint256 timestamp
    );
    
    event ClaimProcessed(
        uint256 indexed policyId,
        uint256 claimAmount,
        uint256 discrepancyPercentage,
        uint256 timestamp
    );
    
    event ModelStakeUpdated(
        address indexed modelProvider,
        uint256 stakedAmount,
        uint256 accuracyScore,
        uint256 timestamp
    );
    
    event OracleReportSubmitted(
        uint256 indexed tokenId,
        uint256 predictedYield,
        uint256 actualYield,
        uint256 confidence,
        uint256 timestamp
    );

    constructor() {
        // Initialize insurance pools
        for (uint256 i = 0; i <= uint256(InsuranceTier.PLATINUM); i++) {
            InsuranceTier tier = InsuranceTier(i);
            insurancePools[tier] = InsurancePool({
                totalReserve: 0,
                activePolicies: 0,
                totalClaimsPaid: 0,
                totalPremiumsCollected: 0,
                lastReserveUpdate: block.timestamp
            });
        }
    }

    /**
     * @dev Create insurance policy with tier-based pricing
     */
    function createPolicy(
        address insured,
        uint256 tokenId,
        uint256 predictedYield,
        uint256 insuredAmount,
        InsuranceTier tier
    ) external payable nonReentrant returns (uint256) {
        require(insured != address(0), "Invalid insured address");
        require(predictedYield > 0, "Invalid predicted yield");
        require(insuredAmount > 0, "Invalid insured amount");
        
        uint256 policyId = ++policyCounter[insured];
        uint256 premium = _calculatePremium(insuredAmount, tier);
        uint256 coverageRate = _getCoverageRate(tier);
        uint256 deductible = _getDeductible(tier);
        
        require(msg.value >= premium, "Insufficient premium payment");
        
        // Create policy
        policies[policyId] = InsurancePolicy({
            policyId: policyId,
            insured: insured,
            tokenId: tokenId,
            predictedYield: predictedYield,
            insuredAmount: insuredAmount,
            premiumPaid: msg.value,
            deductible: deductible,
            coverageRate: coverageRate,
            tier: tier,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + 365 days, // 1 year term
            isActive: true,
            hasClaimed: false
        });
        
        // Update insurance pool
        InsurancePool storage pool = insurancePools[tier];
        pool.totalReserve = pool.totalReserve.add(msg.value);
        pool.totalPremiumsCollected = pool.totalPremiumsCollected.add(msg.value);
        pool.activePolicies = pool.activePolicies.add(1);
        pool.lastReserveUpdate = block.timestamp;
        
        emit PolicyCreated(policyId, insured, tokenId, insuredAmount, tier);
        emit PremiumPaid(policyId, msg.value, block.timestamp);
        
        return policyId;
    }

    /**
     * @dev Process discrepancy claim with multi-layer validation
     */
    function processDiscrepancyClaim(
        uint256 policyId,
        uint256 actualYield,
        uint256[] calldata oracleSourceIds
    ) external onlyOracle nonReentrant {
        InsurancePolicy storage policy = policies[policyId];
        require(policy.isActive, "Policy not active");
        require(!policy.hasClaimed, "Claim already processed");
        require(block.timestamp <= policy.expiresAt, "Policy expired");
        
        // Validate oracle consensus
        OracleReport memory report = _validateOracleConsensus(
            policy.tokenId,
            policy.predictedYield,
            actualYield,
            oracleSourceIds
        );
        
        require(report.isVerified, "Insufficient oracle consensus");
        require(report.confidence >= 700, "Low confidence in oracle data");
        
        // Calculate discrepancy
        uint256 discrepancy = policy.predictedYield > actualYield ? 
            policy.predictedYield - actualYield : 0;
        
        uint256 discrepancyPercentage = (discrepancy * 10000) / policy.predictedYield;
        
        require(discrepancyPercentage >= claimThreshold, "Discrepancy below claim threshold");
        
        // Calculate claim amount
        uint256 claimAmount = _calculateClaimAmount(
            policy.insuredAmount,
            discrepancyPercentage,
            policy.coverageRate,
            policy.deductible
        );
        
        // Check reserve sufficiency
        InsurancePool storage pool = insurancePools[policy.tier];
        require(pool.totalReserve >= claimAmount, "Insufficient reserve funds");
        
        // Process claim
        pool.totalReserve = pool.totalReserve.sub(claimAmount);
        pool.totalClaimsPaid = pool.totalClaimsPaid.add(claimAmount);
        pool.activePolicies = pool.activePolicies.sub(1);
        
        policy.hasClaimed = true;
        policy.isActive = false;
        
        // Transfer claim amount
        payable(policy.insured).transfer(claimAmount);
        
        // Update ML model stakes based on prediction accuracy
        _updateModelStakes(policy.predictedYield, actualYield);
        
        emit ClaimProcessed(policyId, claimAmount, discrepancyPercentage, block.timestamp);
        emit OracleReportSubmitted(policy.tokenId, policy.predictedYield, actualYield, report.confidence, block.timestamp);
    }

    /**
     * @dev Stake tokens for ML model providers
     */
    function stakeModelTokens(uint256 amount) external nonReentrant {
        require(amount >= 1000 * (10**18), "Minimum stake required");
        
        ModelStake storage stake = modelStakes[msg.sender];
        
        if (stake.isActive) {
            stake.stakedAmount = stake.stakedAmount.add(amount);
        } else {
            stake.modelProvider = msg.sender;
            stake.stakedAmount = amount;
            stake.accuracyScore = 500; // Start with neutral score
            stake.totalPredictions = 0;
            stake.lastUpdated = block.timestamp;
            stake.isActive = true;
        }
        
        emit ModelStakeUpdated(msg.sender, stake.stakedAmount, stake.accuracyScore, block.timestamp);
    }

    /**
     * @dev Update model stakes based on prediction accuracy
     */
    function _updateModelStakes(uint256 predictedYield, uint256 actualYield) internal {
        uint256 discrepancy = predictedYield > actualYield ? 
            predictedYield - actualYield : actualYield - predictedYield;
        
        uint256 accuracyPercentage = 10000 - ((discrepancy * 10000) / predictedYield);
        uint256 accuracyScore = accuracyPercentage; // Convert to basis points
        
        // Update all active model stakes (simplified - would track individual model predictions)
        for (uint256 i = 0; i < 100; i++) { // Iterate through potential model providers
            address provider = address(uint160(1000 + i)); // Placeholder for actual model provider addresses
            ModelStake storage stake = modelStakes[provider];
            
            if (stake.isActive) {
                // Update rolling average accuracy
                uint256 newAccuracyScore = (stake.accuracyScore * stake.totalPredictions + accuracyScore) 
                                         / (stake.totalPredictions + 1);
                
                stake.accuracyScore = newAccuracyScore;
                stake.totalPredictions++;
                stake.lastUpdated = block.timestamp;
                
                // Slash or reward based on performance
                if (accuracyPercentage < 8500) { // <85% accuracy
                    uint256 slashAmount = stake.stakedAmount * (8500 - accuracyPercentage) / 10000;
                    stake.stakedAmount = stake.stakedAmount.sub(slashAmount);
                    
                    // Distribute slashed tokens to affected policy holders
                    _distributeSlashedTokens(slashAmount, provider);
                    
                } else if (accuracyPercentage > 9500) { // >95% accuracy
                    uint256 rewardAmount = stake.stakedAmount * (accuracyPercentage - 9500) / 10000;
                    stake.stakedAmount = stake.stakedAmount.add(rewardAmount);
                }
                
                emit ModelStakeUpdated(provider, stake.stakedAmount, stake.accuracyScore, block.timestamp);
            }
        }
    }

    /**
     * @dev Validate oracle consensus
     */
    function _validateOracleConsensus(
        uint256 tokenId,
        uint256 predictedYield,
        uint256 actualYield,
        uint256[] calldata oracleSourceIds
    ) internal view returns (OracleReport memory) {
        require(oracleSourceIds.length >= 3, "Minimum 3 oracle sources required");
        
        uint256[] memory yields = new uint256[](oracleSourceIds.length);
        uint256 validSources = 0;
        
        for (uint256 i = 0; i < oracleSourceIds.length; i++) {
            address oracle = authorizedOracles[uint256(keccak256(abi.encodePacked(oracleSourceIds[i])))];
            if (oracle != address(0)) {
                // In a real implementation, this would query the oracle
                yields[validSources] = actualYield; // Simplified - would get from oracle
                validSources++;
            }
        }
        
        require(validSources >= 3, "Insufficient valid oracle sources");
        
        // Calculate weighted median (simplified)
        uint256 consensusYield = _calculateWeightedMedian(yields, validSources);
        uint256 confidence = _calculateConsensusConfidence(yields, consensusYield, validSources);
        
        return OracleReport({
            tokenId: tokenId,
            predictedYield: predictedYield,
            actualYield: consensusYield,
            confidence: confidence,
            sourceCount: validSources,
            reportedAt: block.timestamp,
            isVerified: confidence >= 700
        });
    }

    /**
     * @dev Calculate weighted median
     */
    function _calculateWeightedMedian(uint256[] memory yields, uint256 count) internal pure returns (uint256) {
        // Simplified median calculation
        uint256[] memory sortedYields = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            sortedYields[i] = yields[i];
        }
        
        // Sort (simplified bubble sort)
        for (uint256 i = 0; i < count - 1; i++) {
            for (uint256 j = 0; j < count - i - 1; j++) {
                if (sortedYields[j] > sortedYields[j + 1]) {
                    uint256 temp = sortedYields[j];
                    sortedYields[j] = sortedYields[j + 1];
                    sortedYields[j + 1] = temp;
                }
            }
        }
        
        return sortedYields[count / 2];
    }

    /**
     * @dev Calculate consensus confidence
     */
    function _calculateConsensusConfidence(
        uint256[] memory yields,
        uint256 consensus,
        uint256 count
    ) internal pure returns (uint256) {
        uint256 totalDeviation = 0;
        
        for (uint256 i = 0; i < count; i++) {
            uint256 deviation = consensus > yields[i] ? 
                consensus - yields[i] : yields[i] - consensus;
            totalDeviation = totalDeviation.add(deviation);
        }
        
        uint256 averageDeviation = totalDeviation / count;
        uint256 confidence = 10000 - (averageDeviation * 10000) / consensus;
        
        return confidence > 10000 ? 0 : confidence;
    }

    /**
     * @dev Calculate premium based on tier and risk factors
     */
    function _calculatePremium(uint256 insuredAmount, InsuranceTier tier) internal pure returns (uint256) {
        uint256 baseRate;
        
        if (tier == InsuranceTier.BRONZE) {
            baseRate = 300; // 3%
        } else if (tier == InsuranceTier.SILVER) {
            baseRate = 250; // 2.5%
        } else if (tier == InsuranceTier.GOLD) {
            baseRate = 200; // 2%
        } else { // PLATINUM
            baseRate = 150; // 1.5%
        }
        
        return (insuredAmount * baseRate) / 10000;
    }

    /**
     * @dev Get coverage rate for tier
     */
    function _getCoverageRate(InsuranceTier tier) internal pure returns (uint256) {
        if (tier == InsuranceTier.BRONZE) return 5000;  // 50%
        if (tier == InsuranceTier.SILVER) return 6000;  // 60%
        if (tier == InsuranceTier.GOLD) return 7000;    // 70%
        return 8000; // PLATINUM: 80%
    }

    /**
     * @dev Get deductible for tier
     */
    function _getDeductible(InsuranceTier tier) internal pure returns (uint256) {
        if (tier == InsuranceTier.BRONZE) return 1000;  // 10%
        if (tier == InsuranceTier.SILVER) return 800;   // 8%
        if (tier == InsuranceTier.GOLD) return 600;     // 6%
        return 500; // PLATINUM: 5%
    }

    /**
     * @dev Calculate claim amount
     */
    function _calculateClaimAmount(
        uint256 insuredAmount,
        uint256 discrepancyPercentage,
        uint256 coverageRate,
        uint256 deductible
    ) internal pure returns (uint256) {
        uint256 lossAmount = (insuredAmount * discrepancyPercentage) / 10000;
        uint256 deductibleAmount = (lossAmount * deductible) / 10000;
        uint256 coveredAmount = (lossAmount * coverageRate) / 10000;
        
        return coveredAmount > deductibleAmount ? coveredAmount - deductibleAmount : 0;
    }

    /**
     * @dev Distribute slashed tokens to affected parties
     */
    function _distributeSlashedTokens(uint256 amount, address modelProvider) internal {
        // In a real implementation, this would distribute to affected policy holders
        // For now, send to contract owner for redistribution
        payable(owner()).transfer(amount);
    }

    /**
     * @dev Admin functions
     */
    function addAuthorizedOracle(string memory oracleId, address oracleAddress) external onlyOwner {
        authorizedOracles[oracleId] = oracleAddress;
    }

    function removeAuthorizedOracle(string memory oracleId) external onlyOwner {
        authorizedOracles[oracleId] = address(0);
    }

    function setYieldOracle(address oracle) external onlyOwner {
        yieldOracle = oracle;
    }

    function setPriceOracle(address oracle) external onlyOwner {
        priceOracle = oracle;
    }

    function updateMinReserveRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 1000 && newRatio <= 5000, "Invalid reserve ratio");
        minReserveRatio = newRatio;
    }

    /**
     * @dev View functions
     */
    function getPolicy(uint256 policyId) external view returns (InsurancePolicy memory) {
        return policies[policyId];
    }

    function getModelStake(address modelProvider) external view returns (ModelStake memory) {
        return modelStakes[modelProvider];
    }

    function getInsurancePool(InsuranceTier tier) external view returns (InsurancePool memory) {
        return insurancePools[tier];
    }

    function calculateQuote(
        uint256 insuredAmount,
        InsuranceTier tier
    ) external view returns (uint256 premium, uint256 coverage, uint256 deductible) {
        premium = _calculatePremium(insuredAmount, tier);
        coverage = _getCoverageRate(tier);
        deductible = _getDeductible(tier);
    }

    /**
     * @dev Emergency functions
     */
    function emergencyPause() external onlyOwner {
        // Implement emergency pause functionality
    }

    function emergencyResume() external onlyOwner {
        // Implement emergency resume functionality
    }
}
