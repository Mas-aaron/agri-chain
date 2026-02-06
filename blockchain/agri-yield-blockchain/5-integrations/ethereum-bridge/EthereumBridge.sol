// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AgriYield Ethereum Bridge
 * @notice Bridges yield tokens from Huawei BCS to Ethereum
 * @dev ERC-1155 implementation with cross-chain capabilities
 */
contract AgriYieldEthereumBridge is ERC1155, Ownable, Pausable, ReentrancyGuard {
    
    // Bridge Oracle (Huawei BCS validator)
    address public bridgeOracle;
    
    // Mapping between BCS Asset IDs and Ethereum Token IDs
    mapping(string => uint256) public bcsToEthereum;
    mapping(uint256 => string) public ethereumToBcs;
    
    // Token metadata
    struct TokenInfo {
        string symbol;
        string cropType;
        uint256 season;
        uint256 predictedYield;
        uint256 actualYield;
        string metadataUri;
        address farmer;
        bool isActive;
    }
    
    mapping(uint256 => TokenInfo) public tokenInfo;
    
    // Loan collateral tracking
    struct Collateral {
        uint256 tokenId;
        uint256 amount;
        uint256 loanId;
        bool isLocked;
        uint256 lockedUntil;
    }
    
    mapping(address => Collateral[]) public userCollaterals;
    
    // Events
    event YieldTokenBridged(
        string indexed bcsAssetId,
        uint256 indexed tokenId,
        address indexed farmer,
        uint256 amount,
        string metadataUri
    );
    
    event TokensLockedForLoan(
        address indexed farmer,
        uint256 indexed loanId,
        uint256[] tokenIds,
        uint256[] amounts
    );
    
    event TokensReleasedFromLoan(
        address indexed farmer,
        uint256 indexed loanId
    );
    
    event TokensTraded(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 price
    );
    
    // Modifiers
    modifier onlyBridgeOracle() {
        require(msg.sender == bridgeOracle, "Caller is not the bridge oracle");
        _;
    }
    
    modifier tokenExists(uint256 tokenId) {
        require(tokenInfo[tokenId].isActive, "Token does not exist");
        _;
    }
    
    constructor(
        address _bridgeOracle
    ) ERC1155("https://api.agriyield.io/token/{id}.json") {
        require(_bridgeOracle != address(0), "Invalid oracle address");
        bridgeOracle = _bridgeOracle;
    }
    
    /**
     * @dev Bridge yield tokens from BCS to Ethereum
     */
    function bridgeYieldToken(
        string memory bcsAssetId,
        address farmer,
        uint256 tokenAmount,
        string memory symbol,
        string memory cropType,
        uint256 season,
        uint256 predictedYield,
        string memory metadataUri
    ) external onlyBridgeOracle nonReentrant returns (uint256) {
        require(farmer != address(0), "Invalid farmer address");
        require(tokenAmount > 0, "Token amount must be positive");
        require(bytes(bcsAssetId).length > 0, "Invalid BCS asset ID");
        
        // Generate unique token ID
        uint256 tokenId = uint256(keccak256(abi.encodePacked(
            bcsAssetId,
            block.chainid,
            block.timestamp
        )));
        
        // Store mappings
        bcsToEthereum[bcsAssetId] = tokenId;
        ethereumToBcs[tokenId] = bcsAssetId;
        
        // Create token info
        tokenInfo[tokenId] = TokenInfo({
            symbol: symbol,
            cropType: cropType,
            season: season,
            predictedYield: predictedYield,
            actualYield: 0,
            metadataUri: metadataUri,
            farmer: farmer,
            isActive: true
        });
        
        // Mint tokens to farmer
        _mint(farmer, tokenId, tokenAmount, "");
        
        emit YieldTokenBridged(
            bcsAssetId,
            tokenId,
            farmer,
            tokenAmount,
            metadataUri
        );
        
        return tokenId;
    }
    
    /**
     * @dev Lock tokens as collateral for a loan
     */
    function lockForLoan(
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256 loanId,
        uint256 durationDays
    ) external nonReentrant {
        require(tokenIds.length == amounts.length, "Arrays length mismatch");
        require(durationDays > 0, "Duration must be positive");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];
            
            require(
                balanceOf(msg.sender, tokenId) >= amount,
                "Insufficient token balance"
            );
            
            // Transfer tokens to contract (locking)
            safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );
            
            // Record collateral
            userCollaterals[msg.sender].push(Collateral({
                tokenId: tokenId,
                amount: amount,
                loanId: loanId,
                isLocked: true,
                lockedUntil: block.timestamp + (durationDays * 1 days)
            }));
        }
        
        emit TokensLockedForLoan(msg.sender, loanId, tokenIds, amounts);
    }
    
    /**
     * @dev Release collateral after loan repayment
     */
    function releaseCollateral(
        address farmer,
        uint256 loanId
    ) external onlyBridgeOracle nonReentrant {
        Collateral[] storage collaterals = userCollaterals[farmer];
        
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i].loanId == loanId && collaterals[i].isLocked) {
                // Return tokens to owner
                safeTransferFrom(
                    address(this),
                    farmer,
                    collaterals[i].tokenId,
                    collaterals[i].amount,
                    ""
                );
                
                collaterals[i].isLocked = false;
            }
        }
        
        emit TokensReleasedFromLoan(farmer, loanId);
    }
    
    /**
     * @dev Liquidate collateral if loan defaults
     */
    function liquidateCollateral(
        address farmer,
        uint256 loanId,
        address liquidator
    ) external onlyBridgeOracle nonReentrant {
        Collateral[] storage collaterals = userCollaterals[farmer];
        
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i].loanId == loanId && collaterals[i].isLocked) {
                // Transfer to liquidator
                safeTransferFrom(
                    address(this),
                    liquidator,
                    collaterals[i].tokenId,
                    collaterals[i].amount,
                    ""
                );
                
                collaterals[i].isLocked = false;
            }
        }
    }
    
    /**
     * @dev Update actual yield from oracle
     */
    function updateActualYield(
        uint256 tokenId,
        uint256 actualYield
    ) external onlyBridgeOracle tokenExists(tokenId) {
        tokenInfo[tokenId].actualYield = actualYield;
    }
    
    /**
     * @dev Get token information
     */
    function getTokenInfo(uint256 tokenId) 
        external 
        view 
        tokenExists(tokenId) 
        returns (TokenInfo memory) 
    {
        return tokenInfo[tokenId];
    }
    
    /**
     * @dev Get token price based on predicted yield
     */
    function getTokenPrice(uint256 tokenId) 
        public 
        view 
        tokenExists(tokenId) 
        returns (uint256) 
    {
        // Base price: $5 per kg predicted yield
        uint256 basePrice = tokenInfo[tokenId].predictedYield * 5 * 10**18;
        
        // Adjust based on accuracy if available
        if (tokenInfo[tokenId].actualYield > 0) {
            uint256 actual = tokenInfo[tokenId].actualYield;
            uint256 predicted = tokenInfo[tokenId].predictedYield;
            
            if (predicted > 0) {
                uint256 accuracy = (actual * 100) / predicted;
                
                // Scale price based on accuracy
                if (accuracy >= 90) {
                    basePrice = (basePrice * 110) / 100;
                } else if (accuracy < 70) {
                    basePrice = (basePrice * 80) / 100;
                }
            }
        }
        
        return basePrice;
    }
    
    /**
     * @dev Batch transfer tokens (for trading)
     */
    function batchTransfer(
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "Not authorized"
        );
        require(tokenIds.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(from, to, tokenIds[i], amounts[i], "");
        }
        
        emit TokensTraded(from, to, tokenIds[0], amounts[0], 0);
    }
    
    /**
     * @dev Override URI for token metadata
     */
    function uri(uint256 tokenId) 
        public 
        view 
        override 
        tokenExists(tokenId) 
        returns (string memory) 
    {
        return tokenInfo[tokenId].metadataUri;
    }
    
    /**
     * @dev Update bridge oracle address
     */
    function setBridgeOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Invalid oracle address");
        bridgeOracle = newOracle;
    }
    
    /**
     * @dev Pause contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
