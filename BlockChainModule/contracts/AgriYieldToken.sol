// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title AgriYieldToken
 * @dev ERC-1155 semi-fungible token for agricultural yield predictions
 * Each token ID represents a unique farm + season + crop combination
 */
contract AgriYieldToken is ERC1155, AccessControl, Pausable {
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /**
     * @dev YieldAsset struct stores metadata for each token
     */
    struct YieldAsset {
        address farmer;           // Token owner/creator
        string farmId;            // Unique farm identifier
        string geoHash;           // Geographic location hash
        string cropType;          // Type of crop (e.g., "Rice", "Wheat")
        uint256 season;           // Season/year identifier
        uint256 predictedYield;   // ML model predicted yield (in kg or units)
        uint256 predictionConfidence; // Confidence score 0-100%
        string dataHash;          // IPFS hash of supporting ML/rover data
        uint256 createdAt;        // Timestamp of token creation
        bool isHarvested;         // Whether harvest data has been recorded
        uint256 actualYield;      // Recorded actual yield after harvest
    }
    
    // Token ID -> YieldAsset metadata
    mapping(uint256 => YieldAsset) public yieldAssets;
    
    // Track next token ID to mint
    uint256 private nextTokenId = 1;
    
    // Base URI for token metadata
    string private baseURI = "ipfs://";
    
    /**
     * @dev Events
     */
    event YieldTokenMinted(
        uint256 indexed tokenId,
        address indexed farmer,
        string farmId,
        string cropType,
        uint256 season,
        uint256 predictedYield,
        uint256 confidence
    );
    
    event YieldUpdated(
        uint256 indexed tokenId,
        uint256 actualYield,
        uint256 timestamp
    );
    
    event BaseURIUpdated(string newBaseURI);
    
    /**
     * @dev Constructor
     * @param uri_ Base URI for token metadata
     */
    constructor(string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        baseURI = uri_;
    }
    
    /**
     * @dev Mint new yield prediction tokens
     * @param farmer Address of the farmer who owns the token
     * @param farmId Unique farm identifier
     * @param geoHash Geographic location hash
     * @param cropType Type of crop
     * @param season Season/year identifier
     * @param predictedYield Predicted yield amount
     * @param predictionConfidence ML model confidence 0-100%
     * @param dataHash IPFS hash of supporting data
     * @return tokenId The ID of the newly minted token
     */
    function mintYieldToken(
        address farmer,
        string memory farmId,
        string memory geoHash,
        string memory cropType,
        uint256 season,
        uint256 predictedYield,
        uint256 predictionConfidence,
        string memory dataHash
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(farmer != address(0), "Invalid farmer address");
        require(predictedYield > 0, "Predicted yield must be greater than 0");
        require(predictionConfidence <= 100, "Confidence must be 0-100");
        require(bytes(farmId).length > 0, "Farm ID required");
        require(bytes(cropType).length > 0, "Crop type required");
        
        uint256 tokenId = nextTokenId++;
        
        yieldAssets[tokenId] = YieldAsset({
            farmer: farmer,
            farmId: farmId,
            geoHash: geoHash,
            cropType: cropType,
            season: season,
            predictedYield: predictedYield,
            predictionConfidence: predictionConfidence,
            dataHash: dataHash,
            createdAt: block.timestamp,
            isHarvested: false,
            actualYield: 0
        });
        
        // Mint tokens to farmer (1 token = 1 unit of predicted yield)
        _mint(farmer, tokenId, predictedYield, "");
        
        emit YieldTokenMinted(
            tokenId,
            farmer,
            farmId,
            cropType,
            season,
            predictedYield,
            predictionConfidence
        );
        
        return tokenId;
    }
    
    /**
     * @dev Update token with actual yield data (post-harvest)
     * Only Oracle role can call this
     * @param tokenId Token to update
     * @param actualYield Actual yield recorded after harvest
     */
    function updateActualYield(
        uint256 tokenId,
        uint256 actualYield
    ) external onlyRole(ORACLE_ROLE) {
        require(yieldAssets[tokenId].createdAt > 0, "Token does not exist");
        require(!yieldAssets[tokenId].isHarvested, "Already harvested");
        
        yieldAssets[tokenId].isHarvested = true;
        yieldAssets[tokenId].actualYield = actualYield;
        
        emit YieldUpdated(tokenId, actualYield, block.timestamp);
    }
    
    /**
     * @dev Get yield asset details
     * @param tokenId Token ID to query
     * @return YieldAsset struct with all metadata
     */
    function getYieldAsset(uint256 tokenId) 
        external 
        view 
        returns (YieldAsset memory) 
    {
        require(yieldAssets[tokenId].createdAt > 0, "Token does not exist");
        return yieldAssets[tokenId];
    }
    
    /**
     * @dev Calculate accuracy of prediction vs actual yield
     * @param tokenId Token to check
     * @return accuracy Percentage of predicted yield vs actual (0-100%)
     */
    function getPredictionAccuracy(uint256 tokenId) 
        external 
        view 
        returns (uint256 accuracy) 
    {
        require(yieldAssets[tokenId].createdAt > 0, "Token does not exist");
        require(yieldAssets[tokenId].isHarvested, "Not yet harvested");
        
        uint256 predicted = yieldAssets[tokenId].predictedYield;
        uint256 actual = yieldAssets[tokenId].actualYield;
        
        if (actual >= predicted) {
            accuracy = 100;
        } else {
            accuracy = (actual * 100) / predicted;
        }
    }
    
    /**
     * @dev Batch transfer tokens (efficient for ERC-1155)
     * @param from Source address
     * @param to Destination address
     * @param ids Array of token IDs
     * @param amounts Array of amounts
     */
    function batchTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "Not authorized"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, "");
    }
    
    /**
     * @dev Pause contract (emergency)
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Update base URI for metadata
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
    
    /**
     * @dev Override URI to return IPFS metadata
     * @param tokenId Token ID
     * @return Metadata URI
     */
    function uri(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require(yieldAssets[tokenId].createdAt > 0, "Token does not exist");
        
        return string(abi.encodePacked(
            baseURI,
            tokenId.toString(),
            ".json"
        ));
    }
    
    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Override _beforeTokenTransfer to enforce pause
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
