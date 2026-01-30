// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AgriAssetRegistry
 * @dev Registry and oracle interface for real-world asset data and yield reconciliation
 */
contract AgriAssetRegistry is AccessControl, ReentrancyGuard {
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    /**
     * @dev Asset registry entry
     */
    struct AssetRegistry {
        uint256 tokenId;
        address tokenContract;
        address farmer;
        string farmId;
        uint256 season;
        uint256 registeredAt;
        string geoLocation;
        string cropVariety;
        uint256 farmSizeHectares;
        bool isActive;
    }
    
    // Token ID -> Asset Registry
    mapping(uint256 => AssetRegistry) public assetRegistry;
    
    // Oracle data reconciliation
    mapping(uint256 => uint256) public oracleUpdatedAt;
    mapping(uint256 => string) public oracleDataHash;
    
    // Farmer -> list of token IDs
    mapping(address => uint256[]) public farmerTokens;
    
    event AssetRegistered(
        uint256 indexed tokenId,
        address indexed farmer,
        string farmId,
        uint256 season
    );
    
    event OracleDataUpdated(
        uint256 indexed tokenId,
        string dataHash,
        uint256 timestamp
    );
    
    event AssetDeactivated(uint256 indexed tokenId);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }
    
    /**
     * @dev Register a yield token as a real-world asset
     */
    function registerAsset(
        uint256 tokenId,
        address tokenContract,
        address farmer,
        string memory farmId,
        uint256 season,
        string memory geoLocation,
        string memory cropVariety,
        uint256 farmSizeHectares
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenContract != address(0), "Invalid token contract");
        require(farmer != address(0), "Invalid farmer");
        require(farmSizeHectares > 0, "Farm size must be greater than 0");
        
        assetRegistry[tokenId] = AssetRegistry({
            tokenId: tokenId,
            tokenContract: tokenContract,
            farmer: farmer,
            farmId: farmId,
            season: season,
            registeredAt: block.timestamp,
            geoLocation: geoLocation,
            cropVariety: cropVariety,
            farmSizeHectares: farmSizeHectares,
            isActive: true
        });
        
        farmerTokens[farmer].push(tokenId);
        
        emit AssetRegistered(tokenId, farmer, farmId, season);
    }
    
    /**
     * @dev Update oracle data for an asset
     */
    function updateOracleData(
        uint256 tokenId,
        string memory dataHash
    ) external onlyRole(ORACLE_ROLE) {
        require(assetRegistry[tokenId].isActive, "Asset not registered or inactive");
        
        oracleUpdatedAt[tokenId] = block.timestamp;
        oracleDataHash[tokenId] = dataHash;
        
        emit OracleDataUpdated(tokenId, dataHash, block.timestamp);
    }
    
    /**
     * @dev Get asset registry details
     */
    function getAssetRegistry(uint256 tokenId)
        external
        view
        returns (AssetRegistry memory)
    {
        require(assetRegistry[tokenId].isActive, "Asset not found");
        return assetRegistry[tokenId];
    }
    
    /**
     * @dev Get all tokens owned by a farmer
     */
    function getFarmerTokens(address farmer)
        external
        view
        returns (uint256[] memory)
    {
        return farmerTokens[farmer];
    }
    
    /**
     * @dev Deactivate an asset (e.g., end of season)
     */
    function deactivateAsset(uint256 tokenId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(assetRegistry[tokenId].isActive, "Asset already inactive");
        assetRegistry[tokenId].isActive = false;
        emit AssetDeactivated(tokenId);
    }
}
