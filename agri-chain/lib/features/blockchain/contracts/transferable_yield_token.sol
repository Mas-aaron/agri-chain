// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TransferableYieldToken
 * @dev Advanced ERC1155 token with phase-based transfer restrictions
 * and comprehensive risk management for agricultural yield tokenization
 */
contract TransferableYieldToken is ERC1155, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Token Lifecycle Phases
    enum TokenPhase {
        PREDICTED,      // Phase 1: Pre-harvest (free trading)
        HARVESTING,     // Phase 2: During harvest (restricted trading)
        SETTLED         // Phase 3: Post-harvest (physical delivery/settlement)
    }

    // Token Information Structure
    struct TokenInfo {
        uint256 tokenId;
        string farmerId;
        string cropType;
        uint256 predictedYield;      // in kg
        uint256 actualYield;         // filled after harvest
        uint256 harvestDate;         // expected harvest timestamp
        TokenPhase currentPhase;
        address originalFarmer;
        uint256 createdAt;
        uint256 settledAt;
        bool isActive;
    }

    // Transfer Restrictions
    struct TransferRestriction {
        bool kycRequired;
        uint256 maxTransferAmount;   // maximum tokens per transfer
        uint256 dailyTransferLimit;   // daily limit per address
        uint256 positionLimit;        // maximum holding per address
        uint256 priceLimitPercent;    // ±10% daily price limit
    }

    // Insurance Policy Structure
    struct InsurancePolicy {
        uint256 policyId;
        address insured;
        uint256 tokenId;
        uint256 insuredAmount;
        uint256 premiumPaid;
        uint256 deductible;           // percentage farmer bears
        uint256 coverageRate;         // percentage insurance covers
        uint256 createdAt;
        bool isActive;
    }

    // State Variables
    mapping(uint256 => TokenInfo) public tokenInfo;
    mapping(uint256 => TokenPhase) public tokenPhases;
    mapping(address => mapping(uint256 => uint256)) public dailyTransferVolume;
    mapping(address => uint256) public tokenHoldings;
    mapping(address => bool) public kycVerified;
    mapping(address => bool) public licensedProcessors;
    mapping(address => bool) public deliveryWarehouses;
    mapping(address => bool) public restrictedParties;
    
    // Insurance mappings
    mapping(uint256 => InsurancePolicy) public insurancePolicies;
    mapping(uint256 => uint256) public policyCounter;
    
    // Oracle interface
    address public yieldOracle;
    address public priceOracle;
    
    // Configuration
    TransferRestriction public transferRestriction;
    uint256 public insuranceReserveRate = 500; // 5% in basis points
    uint256 public stabilizationFundRate = 500; // 5% in basis points
    
    // Events
    event TokenMinted(
        uint256 indexed tokenId,
        address indexed farmer,
        string cropType,
        uint256 amount,
        uint256 predictedYield
    );
    
    event PhaseChanged(
        uint256 indexed tokenId,
        TokenPhase oldPhase,
        TokenPhase newPhase,
        uint256 timestamp
    );
    
    event InsurancePolicyCreated(
        uint256 indexed policyId,
        address indexed insured,
        uint256 tokenId,
        uint256 coverageAmount
    );
    
    event YieldAdjusted(
        uint256 indexed tokenId,
        uint256 oldSupply,
        uint256 newSupply,
        uint256 adjustmentFactor,
        uint256 actualYield
    );
    
    event InsuranceClaimProcessed(
        uint256 indexed policyId,
        uint256 claimAmount,
        uint256 discrepancyPercentage
    );

    constructor() ERC1155("https://api.agrichain.com/metadata/{id}") {
        // Initialize transfer restrictions
        transferRestriction = TransferRestriction({
            kycRequired: true,
            maxTransferAmount: 10000 * (10**18), // 10,000 tokens max per transfer
            dailyTransferLimit: 50000 * (10**18), // 50,000 tokens daily limit
            positionLimit: 100000 * (10**18),     // 100,000 tokens max holding
            priceLimitPercent: 1000                // 10% in basis points
        });
    }

    /**
     * @dev Mint new yield tokens for predicted harvest
     */
    function mintYieldToken(
        address farmer,
        string memory cropType,
        uint256 predictedYield,
        uint256 harvestDate
    ) external onlyOwner nonReentrant returns (uint256) {
        require(farmer != address(0), "Invalid farmer address");
        require(predictedYield > 0, "Invalid predicted yield");
        require(harvestDate > block.timestamp, "Harvest date must be in future");
        
        uint256 tokenId = _generateTokenId();
        uint256 tokenAmount = predictedYield * (10**18); // 1 token = 1 kg
        
        // Create token info
        tokenInfo[tokenId] = TokenInfo({
            tokenId: tokenId,
            farmerId: _addressToFarmerId(farmer),
            cropType: cropType,
            predictedYield: predictedYield,
            actualYield: 0,
            harvestDate: harvestDate,
            currentPhase: TokenPhase.PREDICTED,
            originalFarmer: farmer,
            createdAt: block.timestamp,
            settledAt: 0,
            isActive: true
        });
        
        tokenPhases[tokenId] = TokenPhase.PREDICTED;
        
        // Mint tokens to farmer
        _mint(farmer, tokenId, tokenAmount, "");
        tokenHoldings[farmer] = tokenHoldings[farmer].add(tokenAmount);
        
        emit TokenMinted(tokenId, farmer, cropType, tokenAmount, predictedYield);
        
        return tokenId;
    }

    /**
     * @dev Override transfer function with phase-based restrictions
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view override {
        require(!restrictedParties[to], "Cannot transfer to restricted party");
        require(tokenInfo[tokenId].isActive, "Token is not active");
        
        TokenPhase phase = tokenPhases[tokenId];
        
        if (phase == TokenPhase.PREDICTED) {
            // Phase 1: Free trading with KYC requirements
            _validatePredictedPhaseTransfer(from, to, tokenId, amount);
            
        } else if (phase == TokenPhase.HARVESTING) {
            // Phase 2: Restricted trading
            _validateHarvestingPhaseTransfer(from, to, tokenId, amount);
            
        } else if (phase == TokenPhase.SETTLED) {
            // Phase 3: Physical delivery rights
            _validateSettledPhaseTransfer(from, to, tokenId, amount);
        }
    }

    /**
     * @dev Validate transfers in predicted phase
     */
    function _validatePredictedPhaseTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        // KYC requirement for large transfers
        if (amount > transferRestriction.maxTransferAmount) {
            require(kycVerified[to], "KYC required for large transfers");
        }
        
        // Position limits
        require(
            tokenHoldings[to].add(amount) <= transferRestriction.positionLimit,
            "Exceeds position limit"
        );
        
        // Daily transfer limits
        uint256 today = block.timestamp / 86400;
        uint256 todayVolume = dailyTransferVolume[to][today];
        require(
            todayVolume.add(amount) <= transferRestriction.dailyTransferLimit,
            "Exceeds daily transfer limit"
        );
    }

    /**
     * @dev Validate transfers in harvesting phase
     */
    function _validateHarvestingPhaseTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        TokenInfo memory token = tokenInfo[tokenId];
        
        // Only allow transfers to:
        // 1. Original farmer (buyback)
        // 2. Licensed processors
        // 3. Delivery warehouses
        require(
            to == token.originalFarmer ||
            licensedProcessors[to] ||
            deliveryWarehouses[to],
            "Transfers restricted during harvest"
        );
    }

    /**
     * @dev Validate transfers in settled phase
     */
    function _validateSettledPhaseTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        // Tokens become physical delivery rights
        // Can only transfer to registered delivery recipients
        require(
            deliveryWarehouses[to] || licensedProcessors[to],
            "Recipient must have delivery capacity"
        );
    }

    /**
     * @dev Transition token to harvesting phase
     */
    function transitionToHarvesting(uint256 tokenId) external onlyOwner {
        require(tokenPhases[tokenId] == TokenPhase.PREDICTED, "Invalid phase transition");
        require(block.timestamp >= tokenInfo[tokenId].harvestDate - 30 days, "Too early for harvest");
        
        tokenPhases[tokenId] = TokenPhase.HARVESTING;
        tokenInfo[tokenId].currentPhase = TokenPhase.HARVESTING;
        
        emit PhaseChanged(tokenId, TokenPhase.PREDICTED, TokenPhase.HARVESTING, block.timestamp);
    }

    /**
     * @dev Process actual yield and adjust token supply
     */
    function processActualYield(
        uint256 tokenId,
        uint256 actualYield
    ) external onlyOracle nonReentrant {
        require(tokenInfo[tokenId].isActive, "Token not active");
        require(actualYield > 0, "Invalid actual yield");
        
        TokenInfo storage token = tokenInfo[tokenId];
        uint256 predictedYield = token.predictedYield;
        
        // Update actual yield
        token.actualYield = actualYield;
        
        // Calculate adjustment factor
        uint256 adjustmentFactor;
        uint256 oldSupply = totalSupply(tokenId);
        
        if (actualYield >= predictedYield) {
            // Over-performance: Create bonus tokens
            adjustmentFactor = (actualYield * 1e18) / predictedYield;
            uint256 bonusTokens = oldSupply * (adjustmentFactor - 1e18) / 1e18;
            
            // Mint bonus tokens (50% to farmer, 50% to stabilization fund)
            _mint(token.originalFarmer, tokenId, bonusTokens / 2, "");
            _mint(owner(), tokenId, bonusTokens / 2, ""); // Stabilization fund
            
        } else {
            // Under-performance: Handle discrepancy
            uint256 shortfall = predictedYield - actualYield;
            uint256 shortfallPercentage = (shortfall * 100) / predictedYield;
            
            if (shortfallPercentage <= 10) {
                // Minor shortfall: Proportional token burn
                adjustmentFactor = (actualYield * 1e18) / predictedYield;
                uint256 burnAmount = oldSupply * (1e18 - adjustmentFactor) / 1e18;
                _burn(owner(), tokenId, burnAmount); // Burn from stabilization fund
                
            } else {
                // Major shortfall: Trigger insurance
                _triggerInsuranceClaim(tokenId, shortfall);
                adjustmentFactor = (actualYield * 1e18) / predictedYield;
            }
        }
        
        // Transition to settled phase
        tokenPhases[tokenId] = TokenPhase.SETTLED;
        token.currentPhase = TokenPhase.SETTLED;
        token.settledAt = block.timestamp;
        
        uint256 newSupply = totalSupply(tokenId);
        
        emit YieldAdjusted(tokenId, oldSupply, newSupply, adjustmentFactor, actualYield);
        emit PhaseChanged(tokenId, TokenPhase.HARVESTING, TokenPhase.SETTLED, block.timestamp);
    }

    /**
     * @dev Create insurance policy for a token
     */
    function createInsurancePolicy(
        address insured,
        uint256 tokenId,
        uint256 coverageRate
    ) external payable nonReentrant returns (uint256) {
        require(insurancePolicies[tokenId].policyId == 0, "Policy already exists");
        require(tokenInfo[tokenId].isActive, "Token not active");
        require(coverageRate >= 500 && coverageRate <= 8000, "Invalid coverage rate"); // 5% to 80%
        
        uint256 predictedValue = tokenInfo[tokenId].predictedYield * 1e18; // Assuming 1 ETH per kg
        uint256 insuredAmount = predictedValue * coverageRate / 10000;
        uint256 premium = insuredAmount * 200 / 10000; // 2% premium
        
        require(msg.value >= premium, "Insufficient premium");
        
        uint256 policyId = ++policyCounter;
        
        insurancePolicies[tokenId] = InsurancePolicy({
            policyId: policyId,
            insured: insured,
            tokenId: tokenId,
            insuredAmount: insuredAmount,
            premiumPaid: msg.value,
            deductible: 500, // 5% deductible
            coverageRate: coverageRate,
            createdAt: block.timestamp,
            isActive: true
        });
        
        emit InsurancePolicyCreated(policyId, insured, tokenId, insuredAmount);
        
        return policyId;
    }

    /**
     * @dev Trigger insurance claim for major shortfall
     */
    function _triggerInsuranceClaim(uint256 tokenId, uint256 shortfall) internal {
        InsurancePolicy storage policy = insurancePolicies[tokenId];
        
        if (policy.isActive && shortfall > 0) {
            uint256 claimAmount = shortfall * 1e18 * policy.coverageRate / 10000;
            uint256 deductibleAmount = claimAmount * policy.deductible / 10000;
            uint256 payoutAmount = claimAmount - deductibleAmount;
            
            // Process claim (simplified - would need proper oracle verification)
            if (address(this).balance >= payoutAmount) {
                payable(policy.insured).transfer(payoutAmount);
                policy.isActive = false;
                
                emit InsuranceClaimProcessed(policy.policyId, payoutAmount, (shortfall * 100) / tokenInfo[tokenId].predictedYield);
            }
        }
    }

    /**
     * @dev Admin functions for managing participants
     */
    function setKYCVerified(address participant, bool verified) external onlyOwner {
        kycVerified[participant] = verified;
    }

    function setLicensedProcessor(address processor, bool licensed) external onlyOwner {
        licensedProcessors[processor] = licensed;
    }

    function setDeliveryWarehouse(address warehouse, bool authorized) external onlyOwner {
        deliveryWarehouses[warehouse] = authorized;
    }

    function setRestrictedParty(address party, bool restricted) external onlyOwner {
        restrictedParties[party] = restricted;
    }

    function setYieldOracle(address oracle) external onlyOwner {
        yieldOracle = oracle;
    }

    function setPriceOracle(address oracle) external onlyOwner {
        priceOracle = oracle;
    }

    /**
     * @dev Utility functions
     */
    function _generateTokenId() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender)));
    }

    function _addressToFarmerId(address farmer) internal pure returns (string memory) {
        return uint256(uint160(farmer)).toString();
    }

    /**
     * @dev View functions
     */
    function getTokenInfo(uint256 tokenId) external view returns (TokenInfo memory) {
        return tokenInfo[tokenId];
    }

    function getInsurancePolicy(uint256 tokenId) external view returns (InsurancePolicy memory) {
        return insurancePolicies[tokenId];
    }

    function isTransferAllowed(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external view returns (bool) {
        try this._beforeTokenTransfer(from, to, tokenId, amount) {
            return true;
        } catch {
            return false;
        }
    }
}
