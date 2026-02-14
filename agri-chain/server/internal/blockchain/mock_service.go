package blockchain

import (
	"agrichain-server/internal/metrics"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"
)

type MockService struct {
	mu sync.RWMutex

	// tokenID -> phase
	phases map[string]TokenPhase

	// address -> KYC flag
	kyc map[string]bool

	// tokenID -> address -> holdings (float for now)
	holdings map[string]map[string]float64

	// address -> dayKey -> volume
	dailyVolume map[string]map[string]float64

	transfers []TransferResult

	positionLimitFraction float64
	kycThresholdUSD       float64
	dailyLimitTokens      float64
}

func NewMockService() *MockService {
	return &MockService{
		phases:                map[string]TokenPhase{},
		kyc:                   map[string]bool{},
		holdings:              map[string]map[string]float64{},
		dailyVolume:           map[string]map[string]float64{},
		transfers:             []TransferResult{},
		positionLimitFraction: 0.10,
		kycThresholdUSD:       10000,
		dailyLimitTokens:      50000,
	}
}

func (s *MockService) GetTokenPhase(tokenID string) (TokenPhase, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.phases[tokenID]
	if !ok {
		return PhasePredicted, false
	}
	return p, true
}

func (s *MockService) Transfer(ctx context.Context, req TransferRequest) (TransferResult, *Error) {
	amount, err := strconv.ParseFloat(req.Amount, 64)
	if err != nil || amount <= 0 {
		return TransferResult{}, &Error{Code: "VALIDATION_ERROR", Message: "invalid amount", Details: map[string]any{"amount": req.Amount}}
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	phase := s.phases[req.TokenID]
	if phase == "" {
		phase = PhasePredicted
		s.phases[req.TokenID] = phase
	}

	// Phase rules (server-side enforcement; later mirrored/authoritative on chaincode)
	switch phase {
	case PhasePredicted:
		// ok
	case PhaseHarvesting:
		// only to farmer/processor/warehouse
		role := req.ToRoleHint
		if role == "" {
			role = RoleTrader
		}
		if role != RoleFarmer && role != RoleProcessor && role != RoleWarehouse {
			return TransferResult{}, &Error{Code: "PHASE_RESTRICTED", Message: "transfers restricted during harvesting", Details: map[string]any{"phase": phase, "allowed": []string{string(RoleFarmer), string(RoleProcessor), string(RoleWarehouse)}}}
		}
	case PhaseSettled:
		// only to delivery-capable
		role := req.ToRoleHint
		if role != RoleDelivery && role != RoleWarehouse {
			return TransferResult{}, &Error{Code: "PHASE_RESTRICTED", Message: "transfers restricted during settled phase", Details: map[string]any{"phase": phase, "allowed": []string{string(RoleDelivery), string(RoleWarehouse)}}}
		}
	default:
		return TransferResult{}, &Error{Code: "VALIDATION_ERROR", Message: "unknown phase", Details: map[string]any{"phase": phase}}
	}

	// KYC gate for large value transfers
	if req.FiatValueUSD >= s.kycThresholdUSD {
		if !s.kyc[req.ToAddress] {
			return TransferResult{}, &Error{Code: "KYC_REQUIRED", Message: "KYC required for large transfers", Details: map[string]any{"thresholdUsd": s.kycThresholdUSD}}
		}
	}

	// Daily limit in predicted phase
	dayKey := time.Now().UTC().Format("2006-01-02")
	if s.dailyVolume[req.ToAddress] == nil {
		s.dailyVolume[req.ToAddress] = map[string]float64{}
	}
	if phase == PhasePredicted {
		today := s.dailyVolume[req.ToAddress][dayKey]
		if today+amount > s.dailyLimitTokens {
			return TransferResult{}, &Error{Code: "DAILY_LIMIT", Message: "exceeds daily transfer limit", Details: map[string]any{"limit": s.dailyLimitTokens, "today": today}}
		}
	}

	// Position limit: prevent holdings >10% of supply (mock supply = 1,000,000)
	const mockSupply = 1000000.0
	if s.holdings[req.TokenID] == nil {
		s.holdings[req.TokenID] = map[string]float64{}
	}
	current := s.holdings[req.TokenID][req.ToAddress]
	maxAllowed := mockSupply * s.positionLimitFraction
	if current+amount > maxAllowed {
		return TransferResult{}, &Error{Code: "POSITION_LIMIT", Message: "position limit exceeded", Details: map[string]any{"max": maxAllowed, "current": current}}
	}

	// Apply
	s.holdings[req.TokenID][req.ToAddress] = current + amount
	s.dailyVolume[req.ToAddress][dayKey] = s.dailyVolume[req.ToAddress][dayKey] + amount

	now := time.Now().UTC().Format(time.RFC3339Nano)
	id := shortHash(req.IdempotencyKey + ":" + req.TokenID + ":" + now)
	txid := "TX_" + strings.ToUpper(id)

	result := TransferResult{
		TransferID: "TR_" + id,
		TokenID:    req.TokenID,
		From:       req.FromAddress,
		To:         req.ToAddress,
		Amount:     fmt.Sprintf("%g", amount),
		Phase:      phase,
		TxID:       txid,
		Status:     "SUBMITTED",
	}

	s.transfers = append(s.transfers, result)

	metrics.BlockchainTransfers.WithLabelValues(string(phase), "success").Inc()

	return result, nil
}

func (s *MockService) ListTransfers(ctx context.Context, req ListTransfersRequest) (ListTransfersResult, *Error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var filtered []TransferResult
	for _, t := range s.transfers {
		if req.TokenID != "" && t.TokenID != req.TokenID {
			continue
		}
		if req.FromAddress != "" && t.From != req.FromAddress {
			continue
		}
		if req.ToAddress != "" && t.To != req.ToAddress {
			continue
		}
		filtered = append(filtered, t)
	}

	total := len(filtered)

	// Reverse for latest first
	for i, j := 0, len(filtered)-1; i < j; i, j = i+1, j-1 {
		filtered[i], filtered[j] = filtered[j], filtered[i]
	}

	limit := req.Limit
	if limit <= 0 {
		limit = 10
	}
	offset := req.Offset
	if offset < 0 {
		offset = 0
	}

	end := offset + limit
	if end > total {
		end = total
	}
	if offset > total {
		offset = total
	}

	paginated := filtered[offset:end]

	return ListTransfersResult{
		Transfers: paginated,
		Total:     total,
		Limit:     limit,
		Offset:    offset,
	}, nil
}

func shortHash(s string) string {
	sum := sha256.Sum256([]byte(s))
	h := hex.EncodeToString(sum[:])
	return h[:12]
}
