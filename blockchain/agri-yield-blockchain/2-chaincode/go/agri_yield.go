package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// AgriYieldChaincode implements the tokenization of agricultural yield predictions
type AgriYieldChaincode struct {
	contractapi.Contract
}

// YieldAsset represents a tokenized yield prediction (ERC-1155 style)
type YieldAsset struct {
	AssetID            string    `json:"assetId"`
	TokenID            string    `json:"tokenId"`
	FarmerID           string    `json:"farmerId"`
	FarmerDID          string    `json:"farmerDid"`
	FarmID             string    `json:"farmId"`
	GeoHash            string    `json:"geoHash"`
	CropType           string    `json:"cropType"`
	Season             int       `json:"season"`
	
	// ML Prediction Data
	PredictedYield     float64   `json:"predictedYield"`
	PredictionConfidence float64 `json:"confidence"`
	MLModelVersion     string    `json:"mlModelVersion"`
	MLModelHash        string    `json:"mlModelHash"`
	RoverDataHash      string    `json:"roverDataHash"`
	PredictionDate     time.Time `json:"predictionDate"`
	
	// Token Information
	TokenAmount        int64     `json:"tokenAmount"`
	TokenSymbol        string    `json:"tokenSymbol"`
	TokenDecimals      int       `json:"tokenDecimals"`
	TokenStandard      string    `json:"tokenStandard"`
	
	// Status Tracking
	Status             string    `json:"status"`
	ActualYield        float64   `json:"actualYield"`
	HarvestDate        time.Time `json:"harvestDate"`
	
	// Financial Information
	CurrentValue       float64   `json:"currentValue"`
	Collateralized     bool      `json:"collateralized"`
	LockedForLoan      string    `json:"lockedForLoan"`
	
	// Metadata
	CreatedAt          time.Time `json:"createdAt"`
	UpdatedAt          time.Time `json:"updatedAt"`
	MetadataURI        string    `json:"metadataUri"`
}

// LoanAgreement represents a loan secured by yield tokens
type LoanAgreement struct {
	LoanID           string    `json:"loanId"`
	FarmerID         string    `json:"farmerId"`
	BankID           string    `json:"bankId"`
	AssetIDs         []string  `json:"assetIds"`
	TokenAmount      int64     `json:"tokenAmount"`
	
	// Loan Terms
	LoanAmount       float64   `json:"loanAmount"`
	InterestRate     float64   `json:"interestRate"`
	DurationDays     int       `json:"durationDays"`
	RepaymentDate    time.Time `json:"repaymentDate"`
	
	// Status
	Status           string    `json:"status"`
	AmountRepaid     float64   `json:"amountRepaid"`
	DefaultDate      time.Time `json:"defaultDate"`
	
	// Collateral Management
	CollateralRatio  float64   `json:"collateralRatio"`
	LiquidationPrice float64   `json:"liquidationPrice"`
	
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

// TokenTrade represents a trade of yield tokens
type TokenTrade struct {
	TradeID         string    `json:"tradeId"`
	SellerID        string    `json:"sellerId"`
	BuyerID         string    `json:"buyerId"`
	AssetID         string    `json:"assetId"`
	TokenAmount     int64     `json:"tokenAmount"`
	PricePerToken   float64   `json:"pricePerToken"`
	TotalPrice      float64   `json:"totalPrice"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"createdAt"`
	CompletedAt     time.Time `json:"completedAt"`
}

// Init is called by BCS during chaincode instantiation (delegates to InitLedger)
func (s *AgriYieldChaincode) Init(ctx contractapi.TransactionContextInterface) error {
	return s.InitLedger(ctx)
}

// InitLedger initializes the ledger with sample data
func (s *AgriYieldChaincode) InitLedger(ctx contractapi.TransactionContextInterface) error {
	fmt.Println("Initializing AgriYield Ledger")
	
	// Create sample organizations
	orgs := []string{"FarmerOrg", "BankOrg", "ExchangeOrg", "GovernmentOrg"}
	for _, org := range orgs {
		orgKey := fmt.Sprintf("ORG_%s", org)
		err := ctx.GetStub().PutState(orgKey, []byte(org))
		if err != nil {
			return fmt.Errorf("failed to put organization: %v", err)
		}
	}
	
	// Create sample yield assets
	assets := []YieldAsset{
		{
			AssetID:            "ASSET_2024_WHEAT_001",
			TokenID:            "AYW-2024-WHEAT-001",
			FarmerID:           "FARMER_001",
			FarmerDID:          "did:agri:farmer:001",
			FarmID:            "FARM_001",
			GeoHash:           "9g3w9j",
			CropType:          "Wheat",
			Season:            2024,
			PredictedYield:     5000.5,
			PredictionConfidence: 0.85,
			MLModelVersion:    "v2.1.0",
			MLModelHash:       "QmXyz123...",
			RoverDataHash:     "QmAbc456...",
			TokenAmount:       5000,
			TokenSymbol:       "AYW-2024-WHEAT",
			TokenDecimals:     0,
			TokenStandard:     "ERC-1155",
			Status:            "PREDICTED",
			CurrentValue:      25000.0,
			Collateralized:    false,
			CreatedAt:         time.Now(),
			UpdatedAt:         time.Now(),
			MetadataURI:       "ipfs://QmMetadata1",
		},
	}
	
	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}
		err = ctx.GetStub().PutState(asset.AssetID, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put asset: %v", err)
		}
		
		// Create token balance entry
		balanceKey := fmt.Sprintf("BALANCE_%s_%s", asset.FarmerID, asset.AssetID)
		err = ctx.GetStub().PutState(balanceKey, []byte(strconv.FormatInt(asset.TokenAmount, 10)))
		if err != nil {
			return fmt.Errorf("failed to put balance: %v", err)
		}
	}
	
	fmt.Println("Ledger initialized successfully")
	return nil
}

// CreateYieldAsset tokenizes a yield prediction from ML model
func (s *AgriYieldChaincode) CreateYieldAsset(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	farmerId string,
	farmerDid string,
	farmId string,
	geoHash string,
	cropType string,
	season int,
	predictedYield float64,
	confidence float64,
	mlModelVersion string,
	mlModelHash string,
	roverDataHash string,
	metadataUri string) error {
	
	// Check if asset already exists
	existing, err := ctx.GetStub().GetState(assetId)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("asset %s already exists", assetId)
	}
	
	// Generate token ID
	tokenId := fmt.Sprintf("AYW-%d-%s-%s", season, strings.ToUpper(cropType[:3]), assetId[len(assetId)-3:])
	
	// Calculate token amount
	tokenAmount := int64(predictedYield)
	
	// Create yield asset
	asset := YieldAsset{
		AssetID:            assetId,
		TokenID:            tokenId,
		FarmerID:           farmerId,
		FarmerDID:          farmerDid,
		FarmID:            farmId,
		GeoHash:           geoHash,
		CropType:          cropType,
		Season:            season,
		PredictedYield:    predictedYield,
		PredictionConfidence: confidence,
		MLModelVersion:    mlModelVersion,
		MLModelHash:       mlModelHash,
		RoverDataHash:     roverDataHash,
		PredictionDate:    time.Now(),
		TokenAmount:       tokenAmount,
		TokenSymbol:       fmt.Sprintf("AYW-%d-%s", season, strings.ToUpper(cropType)),
		TokenDecimals:     0,
		TokenStandard:     "ERC-1155",
		Status:            "PREDICTED",
		CurrentValue:      predictedYield * 5.0,
		Collateralized:    false,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
		MetadataURI:       metadataUri,
	}
	
	// Save asset to ledger
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("failed to marshal asset: %v", err)
	}
	
	err = ctx.GetStub().PutState(assetId, assetJSON)
	if err != nil {
		return fmt.Errorf("failed to put asset to ledger: %v", err)
	}
	
	// Initialize farmer's token balance
	balanceKey := fmt.Sprintf("BALANCE_%s_%s", farmerId, assetId)
	err = ctx.GetStub().PutState(balanceKey, []byte(strconv.FormatInt(tokenAmount, 10)))
	if err != nil {
		return fmt.Errorf("failed to set initial balance: %v", err)
	}
	
	// Emit event
	eventPayload := fmt.Sprintf(`{"assetId": "%s", "farmerId": "%s", "tokens": %d, "predictedYield": %f}`,
		assetId, farmerId, tokenAmount, predictedYield)
	err = ctx.GetStub().SetEvent("YieldAssetCreated", []byte(eventPayload))
	if err != nil {
		return fmt.Errorf("failed to emit event: %v", err)
	}
	
	fmt.Printf("Yield asset created: %s with %d tokens\n", assetId, tokenAmount)
	return nil
}

// GetAssetByID retrieves an asset by ID
func (s *AgriYieldChaincode) GetAssetByID(
	ctx contractapi.TransactionContextInterface,
	assetId string) (*YieldAsset, error) {
	
	assetJSON, err := ctx.GetStub().GetState(assetId)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("asset %s does not exist", assetId)
	}
	
	var asset YieldAsset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}
	
	return &asset, nil
}

// GetBalance returns token balance for an owner
func (s *AgriYieldChaincode) GetBalance(
	ctx contractapi.TransactionContextInterface,
	ownerId string,
	assetId string) (int64, error) {
	
	balanceKey := fmt.Sprintf("BALANCE_%s_%s", ownerId, assetId)
	balanceBytes, err := ctx.GetStub().GetState(balanceKey)
	if err != nil {
		return 0, fmt.Errorf("failed to read balance: %v", err)
	}
	
	if balanceBytes == nil {
		return 0, nil
	}
	
	balance, err := strconv.ParseInt(string(balanceBytes), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse balance: %v", err)
	}
	
	return balance, nil
}

// GetAssetsByFarmer returns all assets owned by a farmer
func (s *AgriYieldChaincode) GetAssetsByFarmer(
	ctx contractapi.TransactionContextInterface,
	farmerId string) ([]*YieldAsset, error) {
	
	queryString := fmt.Sprintf(`{
		"selector": {
			"farmerId": "%s"
		}
	}`, farmerId)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer resultsIterator.Close()
	
	var assets []*YieldAsset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to get next query result: %v", err)
		}
		
		var asset YieldAsset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			return nil, err
		}
		
		assets = append(assets, &asset)
	}
	
	return assets, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&AgriYieldChaincode{})
	if err != nil {
		fmt.Printf("Error creating AgriYield chaincode: %v", err)
		return
	}
	
	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting AgriYield chaincode: %v", err)
	}
}
