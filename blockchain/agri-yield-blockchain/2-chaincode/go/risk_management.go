package main

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ─────────────────────────────────────────────────────────────────────────────
// DATA STRUCTURES
// ─────────────────────────────────────────────────────────────────────────────

// InsurancePool tracks collateral and payouts for a single YieldAsset.
type InsurancePool struct {
	AssetID     string    `json:"assetId"`
	PremiumPaid float64   `json:"premiumPaid"`
	PoolBalance float64   `json:"poolBalance"`
	PayoutTotal float64   `json:"payoutTotal"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// InsuranceClaim records one claim triggered by a yield shortfall.
type InsuranceClaim struct {
	ClaimID      string    `json:"claimId"`
	AssetID      string    `json:"assetId"`
	ShortfallPct float64   `json:"shortfallPercent"`
	PayoutAmount float64   `json:"payoutAmount"`
	Status       string    `json:"status"` // PENDING | PAID | REJECTED
	ProcessedAt  time.Time `json:"processedAt"`
}

// FarmerReputation stores on-chain reputation for a farmer.
type FarmerReputation struct {
	FarmerID      string    `json:"farmerId"`
	Score         float64   `json:"score"` // 0–1000
	Tier          string    `json:"tier"`  // Platinum | Gold | Silver | Bronze | New
	TotalHarvests int       `json:"totalHarvests"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

// MLModelStake represents tokens staked by an ML model provider.
type MLModelStake struct {
	ProviderID    string    `json:"providerId"`
	ModelID       string    `json:"modelId"`
	StakeAmount   float64   `json:"stakeAmount"`
	LockedUntil   time.Time `json:"lockedUntil"`
	TotalSlashed  float64   `json:"totalSlashed"`
	TotalRewarded float64   `json:"totalRewarded"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

// PredictionRecord logs discrepancy for a single harvest prediction.
type PredictionRecord struct {
	RecordID    string    `json:"recordId"`
	ModelID     string    `json:"modelId"`
	AssetID     string    `json:"assetId"`
	Season      int       `json:"season"`
	Discrepancy float64   `json:"discrepancyPercent"` // |actual-predicted|/predicted
	RecordedAt  time.Time `json:"recordedAt"`
}

// AdjustmentEvent logs a token supply change after harvest settlement.
type AdjustmentEvent struct {
	EventID          string    `json:"eventId"`
	AssetID          string    `json:"assetId"`
	AdjustmentFactor float64   `json:"adjustmentFactor"` // actual/predicted
	Action           string    `json:"action"`           // MINT_BONUS | BURN_PARTIAL | BURN_SHORTFALL
	TokensDelta      int64     `json:"tokensDelta"`      // positive=minted, negative=burned
	TriggeredAt      time.Time `json:"triggeredAt"`
	IPFSHash         string    `json:"ipfsHash"`
	OracleConfidence float64   `json:"oracleConfidence"`
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

func reputationTier(score float64) string {
	switch {
	case score >= 900:
		return "Platinum"
	case score >= 800:
		return "Gold"
	case score >= 700:
		return "Silver"
	case score >= 600:
		return "Bronze"
	default:
		return "New"
	}
}

func clamp(val, min, max float64) float64 {
	if val < min {
		return min
	}
	if val > max {
		return max
	}
	return val
}

// poolKey returns the ledger key for an InsurancePool.
func poolKey(assetID string) string { return "POOL_" + assetID }

// claimKey returns the ledger key for an InsuranceClaim.
func claimKey(claimID string) string { return "CLAIM_" + claimID }

// reputationKey returns the ledger key for a FarmerReputation.
func reputationKey(farmerID string) string { return "REPUTATION_" + farmerID }

// stakeKey returns the ledger key for an MLModelStake.
func stakeKey(providerId, modelId string) string { return "STAKE_" + providerId + "_" + modelId }

// predRecordKey returns a composite key prefix for PredictionRecords.
func predRecordKey(modelId, assetId string) string { return "PREDREC_" + modelId + "_" + assetId }

// adjEventKey returns the ledger key for an AdjustmentEvent.
func adjEventKey(assetID string) string { return "ADJMNT_" + assetID }

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 2 — INSURANCE POOL
// ─────────────────────────────────────────────────────────────────────────────

// InitInsurancePool creates (or top-ups) an insurance pool for a yield asset.
// Parameters: assetId, premiumAmount (string-encoded float)
func (s *AgriYieldChaincode) InitInsurancePool(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	premiumAmount string,
) error {
	premium, err := strconv.ParseFloat(premiumAmount, 64)
	if err != nil || premium < 0 {
		return fmt.Errorf("invalid premiumAmount: %s", premiumAmount)
	}

	// Verify asset exists
	if _, err := s.GetAssetByID(ctx, assetId); err != nil {
		return fmt.Errorf("asset not found: %v", err)
	}

	key := poolKey(assetId)
	existing, _ := ctx.GetStub().GetState(key)

	var pool InsurancePool
	if existing != nil {
		if err := json.Unmarshal(existing, &pool); err != nil {
			return err
		}
		pool.PremiumPaid += premium
		pool.PoolBalance += premium
	} else {
		pool = InsurancePool{
			AssetID:     assetId,
			PremiumPaid: premium,
			PoolBalance: premium,
			PayoutTotal: 0,
			CreatedAt:   time.Now(),
		}
	}
	pool.UpdatedAt = time.Now()

	poolJSON, err := json.Marshal(pool)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(key, poolJSON); err != nil {
		return fmt.Errorf("failed to save pool: %v", err)
	}

	event := fmt.Sprintf(`{"assetId":"%s","premium":%f,"poolBalance":%f}`,
		assetId, premium, pool.PoolBalance)
	_ = ctx.GetStub().SetEvent("InsurancePoolFunded", []byte(event))
	return nil
}

// GetPoolBalance returns the current insurance pool state for an asset.
func (s *AgriYieldChaincode) GetPoolBalance(
	ctx contractapi.TransactionContextInterface,
	assetId string,
) (*InsurancePool, error) {
	data, err := ctx.GetStub().GetState(poolKey(assetId))
	if err != nil {
		return nil, err
	}
	if data == nil {
		return nil, fmt.Errorf("no insurance pool for asset %s", assetId)
	}
	var pool InsurancePool
	if err := json.Unmarshal(data, &pool); err != nil {
		return nil, err
	}
	return &pool, nil
}

// ProcessClaim triggers an insurance payout when yield shortfall > 5%.
// shortfallPercent is the fraction: (predicted-actual)/predicted (e.g. 0.12 for 12%).
// payoutAmount is the calculated payout (computed by backend).
func (s *AgriYieldChaincode) ProcessClaim(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	shortfallPctStr string,
	payoutAmountStr string,
) error {
	shortfall, err := strconv.ParseFloat(shortfallPctStr, 64)
	if err != nil {
		return fmt.Errorf("invalid shortfallPercent: %v", err)
	}
	payout, err := strconv.ParseFloat(payoutAmountStr, 64)
	if err != nil {
		return fmt.Errorf("invalid payoutAmount: %v", err)
	}

	// Must have a shortfall > 5%
	if shortfall <= 0.05 {
		return fmt.Errorf("shortfall %.2f%% below deductible threshold", shortfall*100)
	}

	// Fetch and update the pool
	pool, err := s.GetPoolBalance(ctx, assetId)
	if err != nil {
		return fmt.Errorf("no pool exists: %v", err)
	}
	if payout > pool.PoolBalance {
		payout = pool.PoolBalance // cap to available balance
	}
	pool.PoolBalance -= payout
	pool.PayoutTotal += payout
	pool.UpdatedAt = time.Now()

	poolJSON, _ := json.Marshal(pool)
	if err := ctx.GetStub().PutState(poolKey(assetId), poolJSON); err != nil {
		return err
	}

	// Record the claim
	claimID := fmt.Sprintf("CLM-%s-%d", assetId, time.Now().UnixNano())
	claim := InsuranceClaim{
		ClaimID:      claimID,
		AssetID:      assetId,
		ShortfallPct: shortfall,
		PayoutAmount: payout,
		Status:       "PAID",
		ProcessedAt:  time.Now(),
	}
	claimJSON, _ := json.Marshal(claim)
	if err := ctx.GetStub().PutState(claimKey(claimID), claimJSON); err != nil {
		return err
	}

	event := fmt.Sprintf(`{"assetId":"%s","claimId":"%s","payout":%f,"remainingPool":%f}`,
		assetId, claimID, payout, pool.PoolBalance)
	_ = ctx.GetStub().SetEvent("InsuranceClaimPaid", []byte(event))
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 3 — DYNAMIC TOKEN ADJUSTMENT
// ─────────────────────────────────────────────────────────────────────────────

// UpdateActualYield records oracle-verified actual yield and triggers
// token adjustment. This is the central settlement function that chains
// all 5 risk layers together.
// Parameters: assetId, actualYield, oracleConfidence, ipfsHash
func (s *AgriYieldChaincode) UpdateActualYield(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	actualYieldStr string,
	oracleConfidenceStr string,
	ipfsHash string,
) error {
	actualYield, err := strconv.ParseFloat(actualYieldStr, 64)
	if err != nil || actualYield < 0 {
		return fmt.Errorf("invalid actualYield: %s", actualYieldStr)
	}
	confidence, err := strconv.ParseFloat(oracleConfidenceStr, 64)
	if err != nil {
		return fmt.Errorf("invalid oracleConfidence: %s", oracleConfidenceStr)
	}

	// Fetch the asset
	asset, err := s.GetAssetByID(ctx, assetId)
	if err != nil {
		return err
	}
	if asset.Status == "HARVESTED" || asset.Status == "SETTLED" {
		return fmt.Errorf("asset %s already settled", assetId)
	}

	// ── Compute adjustment factor ──────────────────────────────
	predicted := asset.PredictedYield
	if predicted == 0 {
		return fmt.Errorf("asset has zero predicted yield")
	}
	factor := actualYield / predicted
	shortfallPct := 0.0
	if factor < 1 {
		shortfallPct = 1 - factor
	}

	// ── Determine token delta ──────────────────────────────────
	totalSupply := asset.TokenAmount
	var tokenDelta int64
	action := "NONE"

	if factor >= 1.0 {
		// Over-performance: mint bonus tokens
		bonusTokens := int64(float64(totalSupply) * (factor - 1.0))
		farmerBonus := bonusTokens / 2
		holdersBonus := bonusTokens - farmerBonus

		// Update farmer balance
		farmerBalKey := fmt.Sprintf("BALANCE_%s_%s", asset.FarmerID, assetId)
		farmerBalBytes, _ := ctx.GetStub().GetState(farmerBalKey)
		farmerBal := int64(0)
		if farmerBalBytes != nil {
			farmerBal, _ = strconv.ParseInt(string(farmerBalBytes), 10, 64)
		}
		farmerBal += farmerBonus
		_ = ctx.GetStub().PutState(farmerBalKey, []byte(strconv.FormatInt(farmerBal, 10)))

		// Distribute holder bonus via event (backend distributes pro-rata)
		tokenDelta = bonusTokens
		action = "MINT_BONUS"
		_ = ctx.GetStub().SetEvent("BonusMinted", []byte(fmt.Sprintf(
			`{"assetId":"%s","farmerBonus":%d,"holdersBonus":%d}`,
			assetId, farmerBonus, holdersBonus,
		)))

	} else if shortfallPct <= 0.10 {
		// Small shortfall (≤10%): proportional burn, no insurance
		burnAmount := int64(float64(totalSupply) * (1.0 - factor))
		tokenDelta = -burnAmount
		action = "BURN_PARTIAL"

	} else {
		// Large shortfall (>10%): trigger insurance claim first, then burn
		// Note: Insurance payout calculation is handled by backend/ProcessClaim.
		// We record the event here; the backend should call ProcessClaim separately.
		tokenDelta = -int64(float64(totalSupply) * shortfallPct)
		action = "BURN_SHORTFALL"
		_ = ctx.GetStub().SetEvent("InsuranceRequired", []byte(fmt.Sprintf(
			`{"assetId":"%s","shortfallPercent":%f,"farmerID":"%s"}`,
			assetId, shortfallPct, asset.FarmerID,
		)))
	}

	// ── Update asset state ─────────────────────────────────────
	asset.ActualYield = actualYield
	asset.HarvestDate = time.Now()
	asset.Status = "HARVESTED"
	asset.UpdatedAt = time.Now()
	asset.TokenAmount = totalSupply + tokenDelta
	if asset.TokenAmount < 0 {
		asset.TokenAmount = 0
	}
	assetJSON, _ := json.Marshal(asset)
	if err := ctx.GetStub().PutState(assetId, assetJSON); err != nil {
		return err
	}

	// ── Store adjustment event ─────────────────────────────────
	adj := AdjustmentEvent{
		EventID:          fmt.Sprintf("ADJ-%s-%d", assetId, time.Now().UnixNano()),
		AssetID:          assetId,
		AdjustmentFactor: factor,
		Action:           action,
		TokensDelta:      tokenDelta,
		TriggeredAt:      time.Now(),
		IPFSHash:         ipfsHash,
		OracleConfidence: confidence,
	}
	adjJSON, _ := json.Marshal(adj)
	_ = ctx.GetStub().PutState(adjEventKey(assetId), adjJSON)

	// ── Emit settlement event ──────────────────────────────────
	_ = ctx.GetStub().SetEvent("YieldSettled", []byte(fmt.Sprintf(
		`{"assetId":"%s","farmerId":"%s","predictedYield":%f,"actualYield":%f,"factor":%f,"tokenDelta":%d,"action":"%s","confidence":%f,"ipfsHash":"%s"}`,
		assetId, asset.FarmerID, predicted, actualYield, factor, tokenDelta, action, confidence, ipfsHash,
	)))

	fmt.Printf("Asset %s settled: factor=%.3f, action=%s, tokenDelta=%d\n",
		assetId, factor, action, tokenDelta)
	return nil
}

// GetAdjustmentEvent retrieves the latest adjustment event for an asset.
func (s *AgriYieldChaincode) GetAdjustmentEvent(
	ctx contractapi.TransactionContextInterface,
	assetId string,
) (*AdjustmentEvent, error) {
	data, err := ctx.GetStub().GetState(adjEventKey(assetId))
	if err != nil || data == nil {
		return nil, fmt.Errorf("no adjustment event for asset %s", assetId)
	}
	var adj AdjustmentEvent
	if err := json.Unmarshal(data, &adj); err != nil {
		return nil, err
	}
	return &adj, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 4 — ML MODEL STAKING
// ─────────────────────────────────────────────────────────────────────────────

// StakeMLModel locks tokens from a provider as model performance collateral.
func (s *AgriYieldChaincode) StakeMLModel(
	ctx contractapi.TransactionContextInterface,
	providerId string,
	modelId string,
	amountStr string,
) error {
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil || amount <= 0 {
		return fmt.Errorf("invalid stake amount: %s", amountStr)
	}

	key := stakeKey(providerId, modelId)
	existing, _ := ctx.GetStub().GetState(key)

	var stake MLModelStake
	if existing != nil {
		if err := json.Unmarshal(existing, &stake); err != nil {
			return err
		}
		stake.StakeAmount += amount
	} else {
		stake = MLModelStake{
			ProviderID:  providerId,
			ModelID:     modelId,
			StakeAmount: amount,
			CreatedAt:   time.Now(),
		}
	}
	stake.UpdatedAt = time.Now()

	stakeJSON, _ := json.Marshal(stake)
	if err := ctx.GetStub().PutState(key, stakeJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("ModelStaked", []byte(fmt.Sprintf(
		`{"providerId":"%s","modelId":"%s","amount":%f,"totalStake":%f}`,
		providerId, modelId, amount, stake.StakeAmount,
	)))
	return nil
}

// UnstakeMLModel releases tokens after a 30-day lock period.
func (s *AgriYieldChaincode) UnstakeMLModel(
	ctx contractapi.TransactionContextInterface,
	providerId string,
	modelId string,
	amountStr string,
) error {
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil || amount <= 0 {
		return fmt.Errorf("invalid unstake amount: %s", amountStr)
	}

	key := stakeKey(providerId, modelId)
	data, err := ctx.GetStub().GetState(key)
	if err != nil || data == nil {
		return fmt.Errorf("no stake found for provider %s, model %s", providerId, modelId)
	}

	var stake MLModelStake
	if err := json.Unmarshal(data, &stake); err != nil {
		return err
	}

	// Check lock period
	if time.Now().Before(stake.LockedUntil) {
		return fmt.Errorf("stake is locked until %s", stake.LockedUntil.Format(time.RFC3339))
	}
	if amount > stake.StakeAmount {
		return fmt.Errorf("insufficient stake: have %.2f, want %.2f", stake.StakeAmount, amount)
	}

	stake.StakeAmount -= amount
	// Re-lock for 30 days on any withdrawal
	stake.LockedUntil = time.Now().Add(30 * 24 * time.Hour)
	stake.UpdatedAt = time.Now()

	stakeJSON, _ := json.Marshal(stake)
	return ctx.GetStub().PutState(key, stakeJSON)
}

// RecordPredictionAccuracy logs the discrepancy for a single harvest.
func (s *AgriYieldChaincode) RecordPredictionAccuracy(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	modelId string,
	discrepancyStr string,
) error {
	discrepancy, err := strconv.ParseFloat(discrepancyStr, 64)
	if err != nil {
		return fmt.Errorf("invalid discrepancy: %s", discrepancyStr)
	}
	discrepancy = clamp(math.Abs(discrepancy), 0, 1)

	// Fetch asset to get season
	asset, err := s.GetAssetByID(ctx, assetId)
	if err != nil {
		return err
	}

	record := PredictionRecord{
		RecordID:    fmt.Sprintf("PREC-%s-%s-%d", modelId, assetId, time.Now().UnixNano()),
		ModelID:     modelId,
		AssetID:     assetId,
		Season:      asset.Season,
		Discrepancy: discrepancy,
		RecordedAt:  time.Now(),
	}
	recJSON, _ := json.Marshal(record)
	recKey := predRecordKey(modelId, assetId)
	return ctx.GetStub().PutState(recKey, recJSON)
}

// SlashStake deducts from provider stake when model performance is poor.
// slashAmountStr: pre-calculated slash amount from backend.
// slashedToStr: who receives the slashed tokens (e.g., "POOL" or holderID).
func (s *AgriYieldChaincode) SlashStake(
	ctx contractapi.TransactionContextInterface,
	providerId string,
	modelId string,
	slashAmountStr string,
) error {
	slashAmount, err := strconv.ParseFloat(slashAmountStr, 64)
	if err != nil || slashAmount <= 0 {
		return fmt.Errorf("invalid slashAmount: %s", slashAmountStr)
	}

	key := stakeKey(providerId, modelId)
	data, err := ctx.GetStub().GetState(key)
	if err != nil || data == nil {
		return fmt.Errorf("no stake found for %s/%s", providerId, modelId)
	}

	var stake MLModelStake
	if err := json.Unmarshal(data, &stake); err != nil {
		return err
	}

	actualSlash := math.Min(slashAmount, stake.StakeAmount)
	stake.StakeAmount -= actualSlash
	stake.TotalSlashed += actualSlash
	stake.UpdatedAt = time.Now()

	stakeJSON, _ := json.Marshal(stake)
	if err := ctx.GetStub().PutState(key, stakeJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("StakeSlashed", []byte(fmt.Sprintf(
		`{"providerId":"%s","modelId":"%s","slashed":%f,"remainingStake":%f}`,
		providerId, modelId, actualSlash, stake.StakeAmount,
	)))
	return nil
}

// RewardStake adds bonus tokens to a provider stake for high accuracy.
func (s *AgriYieldChaincode) RewardStake(
	ctx contractapi.TransactionContextInterface,
	providerId string,
	modelId string,
	rewardAmountStr string,
) error {
	rewardAmount, err := strconv.ParseFloat(rewardAmountStr, 64)
	if err != nil || rewardAmount <= 0 {
		return fmt.Errorf("invalid rewardAmount: %s", rewardAmountStr)
	}

	key := stakeKey(providerId, modelId)
	data, err := ctx.GetStub().GetState(key)
	if err != nil || data == nil {
		return fmt.Errorf("no stake found for %s/%s", providerId, modelId)
	}

	var stake MLModelStake
	if err := json.Unmarshal(data, &stake); err != nil {
		return err
	}

	stake.StakeAmount += rewardAmount
	stake.TotalRewarded += rewardAmount
	stake.UpdatedAt = time.Now()

	stakeJSON, _ := json.Marshal(stake)
	if err := ctx.GetStub().PutState(key, stakeJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("StakeRewarded", []byte(fmt.Sprintf(
		`{"providerId":"%s","modelId":"%s","reward":%f,"totalStake":%f}`,
		providerId, modelId, rewardAmount, stake.StakeAmount,
	)))
	return nil
}

// GetModelStake returns the current stake info for a model provider.
func (s *AgriYieldChaincode) GetModelStake(
	ctx contractapi.TransactionContextInterface,
	providerId string,
	modelId string,
) (*MLModelStake, error) {
	data, err := ctx.GetStub().GetState(stakeKey(providerId, modelId))
	if err != nil || data == nil {
		return nil, fmt.Errorf("no stake found for %s/%s", providerId, modelId)
	}
	var stake MLModelStake
	if err := json.Unmarshal(data, &stake); err != nil {
		return nil, err
	}
	return &stake, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// LAYER 5 — FARMER REPUTATION
// ─────────────────────────────────────────────────────────────────────────────

// UpdateReputation calculates and persists the new reputation score for a farmer.
// Parameters: farmerId, actualYield, predictedYield (both string-encoded floats).
// The chaincode calculates the rolling accuracy score.
func (s *AgriYieldChaincode) UpdateReputation(
	ctx contractapi.TransactionContextInterface,
	farmerId string,
	actualYieldStr string,
	predictedYieldStr string,
) error {
	actual, err := strconv.ParseFloat(actualYieldStr, 64)
	if err != nil {
		return fmt.Errorf("invalid actualYield: %s", actualYieldStr)
	}
	predicted, err := strconv.ParseFloat(predictedYieldStr, 64)
	if err != nil || predicted == 0 {
		return fmt.Errorf("invalid predictedYield: %s", predictedYieldStr)
	}

	// Load existing reputation
	repKey := reputationKey(farmerId)
	data, _ := ctx.GetStub().GetState(repKey)

	var rep FarmerReputation
	if data != nil {
		if err := json.Unmarshal(data, &rep); err != nil {
			return err
		}
	} else {
		rep = FarmerReputation{
			FarmerID:      farmerId,
			Score:         500.0, // start at middle
			TotalHarvests: 0,
		}
	}

	// Accuracy for this harvest: max(0, 1 - |actual-predicted|/predicted) × 1000
	accuracy := math.Max(0, 1.0-math.Abs(actual-predicted)/predicted) * 1000.0

	// Rolling average
	n := float64(rep.TotalHarvests)
	newScore := (rep.Score*n + accuracy) / (n + 1.0)
	newScore = clamp(newScore, 0, 1000)

	rep.Score = newScore
	rep.Tier = reputationTier(newScore)
	rep.TotalHarvests++
	rep.UpdatedAt = time.Now()

	repJSON, _ := json.Marshal(rep)
	if err := ctx.GetStub().PutState(repKey, repJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("ReputationUpdated", []byte(fmt.Sprintf(
		`{"farmerId":"%s","score":%f,"tier":"%s","totalHarvests":%d}`,
		farmerId, rep.Score, rep.Tier, rep.TotalHarvests,
	)))
	return nil
}

// GetReputation retrieves the current reputation for a farmer.
func (s *AgriYieldChaincode) GetReputation(
	ctx contractapi.TransactionContextInterface,
	farmerId string,
) (*FarmerReputation, error) {
	data, err := ctx.GetStub().GetState(reputationKey(farmerId))
	if err != nil {
		return nil, err
	}
	if data == nil {
		// Return default New-tier profile if no history yet
		return &FarmerReputation{
			FarmerID:      farmerId,
			Score:         500.0,
			Tier:          "New",
			TotalHarvests: 0,
			UpdatedAt:     time.Now(),
		}, nil
	}
	var rep FarmerReputation
	if err := json.Unmarshal(data, &rep); err != nil {
		return nil, err
	}
	return &rep, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSFER TOKENS (updated with collateral check)
// ─────────────────────────────────────────────────────────────────────────────

// TransferTokens moves tokens between owners for an asset.
// Enforces that locked (loan-collateral) tokens cannot be transferred.
func (s *AgriYieldChaincode) TransferTokens(
	ctx contractapi.TransactionContextInterface,
	assetId string,
	fromId string,
	toId string,
	amountStr string,
) error {
	amount, err := strconv.ParseInt(amountStr, 10, 64)
	if err != nil || amount <= 0 {
		return fmt.Errorf("invalid amount: %s", amountStr)
	}

	// Check asset not locked
	asset, err := s.GetAssetByID(ctx, assetId)
	if err != nil {
		return err
	}
	if asset.Collateralized && strings.TrimSpace(asset.LockedForLoan) != "" {
		return fmt.Errorf("asset %s is locked as loan collateral", assetId)
	}

	fromKey := fmt.Sprintf("BALANCE_%s_%s", fromId, assetId)
	toKey := fmt.Sprintf("BALANCE_%s_%s", toId, assetId)

	fromBalBytes, err := ctx.GetStub().GetState(fromKey)
	if err != nil {
		return err
	}
	fromBal := int64(0)
	if fromBalBytes != nil {
		fromBal, _ = strconv.ParseInt(string(fromBalBytes), 10, 64)
	}
	if fromBal < amount {
		return fmt.Errorf("insufficient balance: %d < %d", fromBal, amount)
	}

	toBalBytes, _ := ctx.GetStub().GetState(toKey)
	toBal := int64(0)
	if toBalBytes != nil {
		toBal, _ = strconv.ParseInt(string(toBalBytes), 10, 64)
	}

	fromBal -= amount
	toBal += amount

	if err := ctx.GetStub().PutState(fromKey, []byte(strconv.FormatInt(fromBal, 10))); err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(toKey, []byte(strconv.FormatInt(toBal, 10))); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("TokensTransferred", []byte(fmt.Sprintf(
		`{"assetId":"%s","from":"%s","to":"%s","amount":%d}`,
		assetId, fromId, toId, amount,
	)))
	return nil
}

// CreateLoanAgreement locks tokens as collateral for a loan.
func (s *AgriYieldChaincode) CreateLoanAgreement(
	ctx contractapi.TransactionContextInterface,
	loanId string,
	farmerId string,
	bankId string,
	assetId string,
	loanAmountStr string,
	interestRateStr string,
	durationDaysStr string,
) error {
	loanAmount, err := strconv.ParseFloat(loanAmountStr, 64)
	if err != nil {
		return fmt.Errorf("invalid loanAmount: %v", err)
	}
	interestRate, err := strconv.ParseFloat(interestRateStr, 64)
	if err != nil {
		return fmt.Errorf("invalid interestRate: %v", err)
	}
	durationDays, err := strconv.Atoi(durationDaysStr)
	if err != nil {
		return fmt.Errorf("invalid durationDays: %v", err)
	}

	asset, err := s.GetAssetByID(ctx, assetId)
	if err != nil {
		return err
	}
	if asset.Collateralized {
		return fmt.Errorf("asset %s already used as collateral", assetId)
	}

	asset.Collateralized = true
	asset.LockedForLoan = loanId
	asset.UpdatedAt = time.Now()

	assetJSON, _ := json.Marshal(asset)
	if err := ctx.GetStub().PutState(assetId, assetJSON); err != nil {
		return err
	}

	loan := LoanAgreement{
		LoanID:        loanId,
		FarmerID:      farmerId,
		BankID:        bankId,
		AssetIDs:      []string{assetId},
		TokenAmount:   asset.TokenAmount,
		LoanAmount:    loanAmount,
		InterestRate:  interestRate,
		DurationDays:  durationDays,
		RepaymentDate: time.Now().Add(time.Duration(durationDays) * 24 * time.Hour),
		Status:        "ACTIVE",
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
	loanJSON, _ := json.Marshal(loan)
	loanKey := "LOAN_" + loanId
	if err := ctx.GetStub().PutState(loanKey, loanJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("LoanCreated", []byte(fmt.Sprintf(
		`{"loanId":"%s","farmerId":"%s","bankId":"%s","assetId":"%s","amount":%f}`,
		loanId, farmerId, bankId, assetId, loanAmount,
	)))
	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
// INDEPENDENT VERIFIER — ON-CHAIN FUNCTIONS
// ─────────────────────────────────────────────────────────────────────────────

// VerifierProfile represents a registered independent verifier on-chain.
type VerifierProfile struct {
	VerifierID       string    `json:"verifierId"`
	OrganizationName string    `json:"organizationName"`
	OrganizationType string    `json:"organizationType"` // GOVERNMENT | UNIVERSITY | SATELLITE | INSPECTOR | COOPERATIVE
	StakeAmount      float64   `json:"stakeAmount"`
	ReputationScore  int       `json:"reputationScore"` // 0–1000
	TotalSubmissions int       `json:"totalSubmissions"`
	IsActive         bool      `json:"isActive"`
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

// VerifierSubmission records a single yield report from a verifier.
type VerifierSubmission struct {
	SubmissionID   string    `json:"submissionId"`
	AssetID        string    `json:"assetId"`
	VerifierID     string    `json:"verifierId"`
	SubmittedYield float64   `json:"submittedYield"`
	Confidence     float64   `json:"confidence"`
	DataSource     string    `json:"dataSource"`
	Status         string    `json:"status"` // PENDING | ACCEPTED | REJECTED
	SubmittedAt    time.Time `json:"submittedAt"`
}

// VerifierConsensus stores the final consensus formed from multiple verifier submissions.
type VerifierConsensus struct {
	ConsensusID     string    `json:"consensusId"`
	AssetID         string    `json:"assetId"`
	ConsensusYield  float64   `json:"consensusYield"`
	Confidence      float64   `json:"confidence"`
	SubmissionCount int       `json:"submissionCount"`
	IPFSHash        string    `json:"ipfsHash"`
	CreatedAt       time.Time `json:"createdAt"`
}

// verifierKey returns the ledger key for a VerifierProfile.
func verifierKey(verifierId string) string { return "VERIFIER_" + verifierId }

// verifierSubKey returns the ledger key for a VerifierSubmission.
func verifierSubKey(submissionId string) string { return "VSUB_" + submissionId }

// verifierConsensusKey returns the ledger key for a VerifierConsensus.
func verifierConsensusKey(assetId string) string { return "VCONS_" + assetId }

// verifierStakeKey returns the ledger key for verifier staked tokens.
func verifierStakeKey(verifierId string) string { return "VSTAKE_" + verifierId }

// RegisterVerifier creates a new verifier profile on the ledger.
// Parameters: verifierId, organizationName, organizationType
func (s *AgriYieldChaincode) RegisterVerifier(
	ctx contractapi.TransactionContextInterface,
	verifierId string,
	organizationName string,
	organizationType string,
) error {
	key := verifierKey(verifierId)
	existing, _ := ctx.GetStub().GetState(key)
	if existing != nil {
		return fmt.Errorf("verifier %s already registered", verifierId)
	}

	profile := VerifierProfile{
		VerifierID:       verifierId,
		OrganizationName: organizationName,
		OrganizationType: organizationType,
		StakeAmount:      0,
		ReputationScore:  500,
		TotalSubmissions: 0,
		IsActive:         true,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	profileJSON, err := json.Marshal(profile)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(key, profileJSON); err != nil {
		return fmt.Errorf("failed to save verifier: %v", err)
	}

	_ = ctx.GetStub().SetEvent("VerifierRegistered", []byte(fmt.Sprintf(
		`{"verifierId":"%s","organizationName":"%s","organizationType":"%s"}`,
		verifierId, organizationName, organizationType,
	)))
	return nil
}

// GetVerifier retrieves a verifier profile from the ledger.
func (s *AgriYieldChaincode) GetVerifier(
	ctx contractapi.TransactionContextInterface,
	verifierId string,
) (*VerifierProfile, error) {
	data, err := ctx.GetStub().GetState(verifierKey(verifierId))
	if err != nil {
		return nil, err
	}
	if data == nil {
		return nil, fmt.Errorf("verifier %s not found", verifierId)
	}
	var profile VerifierProfile
	if err := json.Unmarshal(data, &profile); err != nil {
		return nil, err
	}
	return &profile, nil
}

// SubmitVerifierReport records a yield report from a verifier on-chain.
// Parameters: submissionId, assetId, verifierId, submittedYield, confidence, dataSource
func (s *AgriYieldChaincode) SubmitVerifierReport(
	ctx contractapi.TransactionContextInterface,
	submissionId string,
	assetId string,
	verifierId string,
	submittedYieldStr string,
	confidenceStr string,
	dataSource string,
) error {
	yieldVal, err := strconv.ParseFloat(submittedYieldStr, 64)
	if err != nil || yieldVal < 0 {
		return fmt.Errorf("invalid submittedYield: %s", submittedYieldStr)
	}
	conf, err := strconv.ParseFloat(confidenceStr, 64)
	if err != nil {
		return fmt.Errorf("invalid confidence: %s", confidenceStr)
	}

	// Verify the verifier exists and is active
	vProfile, err := s.GetVerifier(ctx, verifierId)
	if err != nil {
		return fmt.Errorf("verifier not found: %v", err)
	}
	if !vProfile.IsActive {
		return fmt.Errorf("verifier %s is suspended", verifierId)
	}

	sub := VerifierSubmission{
		SubmissionID:   submissionId,
		AssetID:        assetId,
		VerifierID:     verifierId,
		SubmittedYield: yieldVal,
		Confidence:     conf,
		DataSource:     dataSource,
		Status:         "PENDING",
		SubmittedAt:    time.Now(),
	}

	subJSON, _ := json.Marshal(sub)
	if err := ctx.GetStub().PutState(verifierSubKey(submissionId), subJSON); err != nil {
		return err
	}

	// Update verifier submission count
	vProfile.TotalSubmissions++
	vProfile.UpdatedAt = time.Now()
	vpJSON, _ := json.Marshal(vProfile)
	_ = ctx.GetStub().PutState(verifierKey(verifierId), vpJSON)

	_ = ctx.GetStub().SetEvent("VerifierReportSubmitted", []byte(fmt.Sprintf(
		`{"submissionId":"%s","assetId":"%s","verifierId":"%s","yield":%f,"confidence":%f}`,
		submissionId, assetId, verifierId, yieldVal, conf,
	)))
	return nil
}

// RecordVerifierConsensus stores the final consensus from verifier submissions on-chain.
// Called by the backend after the weighted-median consensus is computed off-chain.
// Parameters: consensusId, assetId, consensusYield, confidence, submissionCount, ipfsHash
func (s *AgriYieldChaincode) RecordVerifierConsensus(
	ctx contractapi.TransactionContextInterface,
	consensusId string,
	assetId string,
	consensusYieldStr string,
	confidenceStr string,
	submissionCountStr string,
	ipfsHash string,
) error {
	consensusYield, err := strconv.ParseFloat(consensusYieldStr, 64)
	if err != nil {
		return fmt.Errorf("invalid consensusYield: %s", consensusYieldStr)
	}
	confidence, err := strconv.ParseFloat(confidenceStr, 64)
	if err != nil {
		return fmt.Errorf("invalid confidence: %s", confidenceStr)
	}
	submissionCount, err := strconv.Atoi(submissionCountStr)
	if err != nil {
		return fmt.Errorf("invalid submissionCount: %s", submissionCountStr)
	}

	consensus := VerifierConsensus{
		ConsensusID:     consensusId,
		AssetID:         assetId,
		ConsensusYield:  consensusYield,
		Confidence:      confidence,
		SubmissionCount: submissionCount,
		IPFSHash:        ipfsHash,
		CreatedAt:       time.Now(),
	}

	consJSON, _ := json.Marshal(consensus)
	if err := ctx.GetStub().PutState(verifierConsensusKey(assetId), consJSON); err != nil {
		return err
	}

	_ = ctx.GetStub().SetEvent("VerifierConsensusRecorded", []byte(fmt.Sprintf(
		`{"consensusId":"%s","assetId":"%s","consensusYield":%f,"confidence":%f,"submissions":%d,"ipfsHash":"%s"}`,
		consensusId, assetId, consensusYield, confidence, submissionCount, ipfsHash,
	)))
	return nil
}

// GetVerifierConsensus retrieves the consensus report for an asset.
func (s *AgriYieldChaincode) GetVerifierConsensus(
	ctx contractapi.TransactionContextInterface,
	assetId string,
) (*VerifierConsensus, error) {
	data, err := ctx.GetStub().GetState(verifierConsensusKey(assetId))
	if err != nil || data == nil {
		return nil, fmt.Errorf("no verifier consensus for asset %s", assetId)
	}
	var consensus VerifierConsensus
	if err := json.Unmarshal(data, &consensus); err != nil {
		return nil, err
	}
	return &consensus, nil
}

// StakeVerifierTokens locks tokens as a verifier stake to increase voting weight.
// Parameters: verifierId, amount
func (s *AgriYieldChaincode) StakeVerifierTokens(
	ctx contractapi.TransactionContextInterface,
	verifierId string,
	amountStr string,
) error {
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil || amount <= 0 {
		return fmt.Errorf("invalid stake amount: %s", amountStr)
	}

	// Update verifier profile stake
	vProfile, err := s.GetVerifier(ctx, verifierId)
	if err != nil {
		return fmt.Errorf("verifier not found: %v", err)
	}

	vProfile.StakeAmount += amount
	vProfile.UpdatedAt = time.Now()
	vpJSON, _ := json.Marshal(vProfile)
	if err := ctx.GetStub().PutState(verifierKey(verifierId), vpJSON); err != nil {
		return err
	}

	// Store individual stake record
	stakeData := fmt.Sprintf(`{"verifierId":"%s","stakeAmount":%f,"totalStake":%f,"stakedAt":"%s"}`,
		verifierId, amount, vProfile.StakeAmount, time.Now().Format(time.RFC3339))
	_ = ctx.GetStub().PutState(verifierStakeKey(verifierId), []byte(stakeData))

	_ = ctx.GetStub().SetEvent("VerifierStaked", []byte(fmt.Sprintf(
		`{"verifierId":"%s","amount":%f,"totalStake":%f}`,
		verifierId, amount, vProfile.StakeAmount,
	)))
	return nil
}

// GetVerifierStake returns the current stake info for a verifier.
func (s *AgriYieldChaincode) GetVerifierStake(
	ctx contractapi.TransactionContextInterface,
	verifierId string,
) (string, error) {
	data, err := ctx.GetStub().GetState(verifierStakeKey(verifierId))
	if err != nil || data == nil {
		return "", fmt.Errorf("no stake found for verifier %s", verifierId)
	}
	return string(data), nil
}
