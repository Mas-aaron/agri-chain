package legacy

import (
	"agrichain-server/internal/api/response"
	"agrichain-server/internal/blockchain"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

type ChainTx struct {
	From      string `json:"from"`
	To        string `json:"to"`
	Amount    string `json:"amount"`
	CreatedAt string `json:"createdAt"`
	TxHash    string `json:"txHash"`
}

type ChainBlock struct {
	Index        int       `json:"index"`
	Timestamp    string    `json:"timestamp"`
	Transactions []ChainTx `json:"transactions"`
	PrevHash     string    `json:"prevHash"`
	Nonce        uint64    `json:"nonce"`
	Difficulty   int       `json:"difficulty"`
	Hash         string    `json:"hash"`
}

type InMemoryBlockchain struct {
	mu         sync.RWMutex
	chain      []ChainBlock
	pendingTxs []ChainTx
	difficulty int
}

func newInMemoryBlockchain(difficulty int) *InMemoryBlockchain {
	bc := &InMemoryBlockchain{difficulty: difficulty}
	genesis := ChainBlock{
		Index:        0,
		Timestamp:    time.Now().UTC().Format(time.RFC3339Nano),
		Transactions: []ChainTx{},
		PrevHash:     "",
		Nonce:        0,
		Difficulty:   difficulty,
	}
	genesis.Hash = hashBlock(genesis)
	bc.chain = []ChainBlock{genesis}
	return bc
}

func (bc *InMemoryBlockchain) addPendingTx(tx ChainTx) {
	bc.mu.Lock()
	defer bc.mu.Unlock()
	bc.pendingTxs = append(bc.pendingTxs, tx)
}

func (bc *InMemoryBlockchain) minePendingTxs() (ChainBlock, bool) {
	bc.mu.Lock()
	defer bc.mu.Unlock()
	if len(bc.pendingTxs) == 0 {
		return ChainBlock{}, false
	}
	prev := bc.chain[len(bc.chain)-1]
	block := ChainBlock{
		Index:        prev.Index + 1,
		Timestamp:    time.Now().UTC().Format(time.RFC3339Nano),
		Transactions: append([]ChainTx{}, bc.pendingTxs...),
		PrevHash:     prev.Hash,
		Difficulty:   bc.difficulty,
	}

	prefix := strings.Repeat("0", bc.difficulty)
	for {
		block.Hash = hashBlock(block)
		if strings.HasPrefix(block.Hash, prefix) {
			break
		}
		block.Nonce++
	}

	bc.chain = append(bc.chain, block)
	bc.pendingTxs = nil
	return block, true
}

func (bc *InMemoryBlockchain) snapshot() (chain []ChainBlock, pending []ChainTx) {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	chain = append([]ChainBlock{}, bc.chain...)
	pending = append([]ChainTx{}, bc.pendingTxs...)
	return
}

func (bc *InMemoryBlockchain) tamperBlock(index int) bool {
	bc.mu.Lock()
	defer bc.mu.Unlock()
	if index <= 0 || index >= len(bc.chain) {
		return false
	}
	if len(bc.chain[index].Transactions) == 0 {
		bc.chain[index].Transactions = []ChainTx{{From: "tamper", To: "tamper", Amount: "0", CreatedAt: time.Now().UTC().Format(time.RFC3339Nano), TxHash: "0x"}}
		return true
	}
	bc.chain[index].Transactions[0].Amount = bc.chain[index].Transactions[0].Amount + "_tampered"
	return true
}

func (bc *InMemoryBlockchain) validate() (bool, string) {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	if len(bc.chain) == 0 {
		return false, "empty chain"
	}
	prefix := strings.Repeat("0", bc.difficulty)
	for i := 0; i < len(bc.chain); i++ {
		b := bc.chain[i]
		expected := hashBlock(b)
		if b.Hash != expected {
			return false, fmt.Sprintf("invalid hash at index %d", b.Index)
		}
		if !strings.HasPrefix(b.Hash, prefix) && b.Index != 0 {
			return false, fmt.Sprintf("difficulty not satisfied at index %d", b.Index)
		}
		if i == 0 {
			if b.PrevHash != "" {
				return false, "genesis prevHash must be empty"
			}
			continue
		}
		prev := bc.chain[i-1]
		if b.PrevHash != prev.Hash {
			return false, fmt.Sprintf("broken prevHash link at index %d", b.Index)
		}
	}
	return true, "ok"
}

func hashBlock(b ChainBlock) string {
	tmp := b
	tmp.Hash = ""
	buf, _ := json.Marshal(tmp)
	sum := sha256.Sum256(buf)
	return hex.EncodeToString(sum[:])
}

func hashTx(tx ChainTx) string {
	buf, _ := json.Marshal(tx)
	sum := sha256.Sum256(buf)
	return hex.EncodeToString(sum[:])
}

func pseudoAddress(seed string) string {
	sum := sha256.Sum256([]byte(seed))
	return "0x" + hex.EncodeToString(sum[:])[:40]
}

type YieldAsset struct {
	AssetId        string     `json:"assetId"`
	TokenId        string     `json:"tokenId"`
	FarmerId       string     `json:"farmerId"`
	CropType       string     `json:"cropType"`
	Season         int        `json:"season"`
	PredictedYield float64    `json:"predictedYield"`
	Confidence     float64    `json:"confidence"`
	TokenAmount    float64    `json:"tokenAmount"`
	CurrentValue   float64    `json:"currentValue"`
	Status         string     `json:"status"`
	CreatedAt      time.Time  `json:"createdAt"`
	UpdatedAt      *time.Time `json:"updatedAt"`
}

type TradeRequest struct {
	AssetId    string  `json:"assetId"`
	Amount     float64 `json:"amount"`
	TradeType  string  `json:"tradeType"`
	FarmerId   string  `json:"farmerId"`
	Timestamp  string  `json:"timestamp"`
	RequestId  string  `json:"requestId"`
	Reference  string  `json:"reference"`
	MarketNote string  `json:"marketNote"`
}

type WalletConnectResponse struct {
	Success   bool   `json:"success"`
	Address   string `json:"address"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
}

type WalletStatusResponse struct {
	IsConnected bool   `json:"isConnected"`
	Address     string `json:"address"`
	Timestamp   string `json:"timestamp"`
}

type SendTransactionRequest struct {
	From   string `json:"from"`
	To     string `json:"to"`
	Amount string `json:"amount"`
}

type SendTransactionResponse struct {
	Success         bool   `json:"success"`
	TransactionHash string `json:"transactionHash"`
	Message         string `json:"message"`
	Timestamp       string `json:"timestamp"`
}

type TokenizeYieldRequest struct {
	FarmerId    string `json:"farmerId"`
	YieldAmount string `json:"yieldAmount"`
	CropType    string `json:"cropType"`
}

type AdvancedTokenizeRequest struct {
	FarmerId       string  `json:"farmerId"`
	CropType       string  `json:"cropType"`
	PredictedYield float64 `json:"predictedYield"`
	HarvestDate    string  `json:"harvestDate"`
	InsuranceTier  string  `json:"insuranceTier"`
}

type TransferTokensRequest struct {
	TokenId   string  `json:"tokenId"`
	ToAddress string  `json:"toAddress"`
	Amount    float64 `json:"amount"`
}

type InsurancePolicyRequest struct {
	TokenId        string  `json:"tokenId"`
	FarmerId       string  `json:"farmerId"`
	PredictedYield float64 `json:"predictedYield"`
	Tier           string  `json:"tier"`
}

type ProcessYieldRequest struct {
	TokenId     string  `json:"tokenId"`
	ActualYield float64 `json:"actualYield"`
}

type InsuranceClaimRequest struct {
	TokenId      string  `json:"tokenId"`
	Discrepancy  float64 `json:"discrepancy"`
	PolicyIdHint string  `json:"policyId"`
}

type Store interface {
	ListAssetsByFarmer(farmerId string) ([]YieldAsset, bool)
	GetAsset(assetId string) (YieldAsset, bool)
	CreateAsset(asset YieldAsset) (YieldAsset, error)
	UpdateAsset(assetId string, asset YieldAsset) (YieldAsset, bool, error)
	DeleteAsset(assetId string) bool
	GetPortfolioSummary(farmerId string) (map[string]any, error)
	ExecuteTrade(req TradeRequest) (map[string]any, error)
	GetMarketData(cropType string) (map[string]any, error)
}

type memoryStore struct {
	mu     sync.RWMutex
	assets map[string]YieldAsset
}

func newMemoryStore() *memoryStore {
	return &memoryStore{assets: map[string]YieldAsset{}}
}

func (s *memoryStore) ListAssetsByFarmer(farmerId string) ([]YieldAsset, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	res := make([]YieldAsset, 0)
	for _, a := range s.assets {
		if a.FarmerId == farmerId {
			res = append(res, a)
		}
	}
	return res, true
}

func (s *memoryStore) GetAsset(assetId string) (YieldAsset, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.assets[assetId]
	return a, ok
}

func (s *memoryStore) CreateAsset(asset YieldAsset) (YieldAsset, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if asset.AssetId == "" {
		asset.AssetId = "ASSET_" + strings.ReplaceAll(time.Now().UTC().Format("20060102_150405.000"), ".", "_")
	}
	if asset.TokenId == "" {
		asset.TokenId = asset.AssetId
	}
	now := time.Now().UTC()
	if asset.CreatedAt.IsZero() {
		asset.CreatedAt = now
	}
	s.assets[asset.AssetId] = asset
	return asset, nil
}

func (s *memoryStore) UpdateAsset(assetId string, asset YieldAsset) (YieldAsset, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.assets[assetId]
	if !ok {
		return YieldAsset{}, false, nil
	}
	asset.AssetId = assetId
	now := time.Now().UTC()
	asset.UpdatedAt = &now
	s.assets[assetId] = asset
	return asset, true, nil
}

func (s *memoryStore) DeleteAsset(assetId string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.assets[assetId]; !ok {
		return false
	}
	delete(s.assets, assetId)
	return true
}

func (s *memoryStore) GetPortfolioSummary(farmerId string) (map[string]any, error) {
	assets, _ := s.ListAssetsByFarmer(farmerId)
	assetCount := len(assets)
	var totalValue float64
	var avgConfidence float64
	for _, a := range assets {
		totalValue += a.CurrentValue
		avgConfidence += a.Confidence
	}
	if assetCount > 0 {
		avgConfidence = avgConfidence / float64(assetCount)
	}
	return map[string]any{
		"farmerId":        farmerId,
		"assetCount":      assetCount,
		"totalValue":      totalValue,
		"avgConfidence":   avgConfidence,
		"lastUpdatedAt":   time.Now().UTC().Format(time.RFC3339),
		"currency":        "USD",
		"valuationMethod": "mock",
	}, nil
}

func (s *memoryStore) ExecuteTrade(req TradeRequest) (map[string]any, error) {
	now := time.Now().UTC()
	return map[string]any{
		"transactionId": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
		"assetId":       req.AssetId,
		"amount":        req.Amount,
		"tradeType":     req.TradeType,
		"status":        "SUCCESS",
		"executedAt":    now.Format(time.RFC3339),
	}, nil
}

func (s *memoryStore) GetMarketData(cropType string) (map[string]any, error) {
	return map[string]any{
		"cropType":   cropType,
		"price":      1.0,
		"currency":   "USD",
		"volume":     0,
		"trend":      "FLAT",
		"source":     "mock",
		"updatedAt":  time.Now().UTC().Format(time.RFC3339),
		"confidence": 0.2,
	}, nil
}

type App struct {
	store           Store
	bc              *InMemoryBlockchain
	mux             *http.ServeMux
	walletConnected bool
	walletAddress   string
	blockchainSvc   blockchain.Service
}

func NewApp() *App {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("LEDGER_MODE")))
	var store Store
	if mode == "fabric" {
		store = newMemoryStore()
	} else {
		store = newMemoryStore()
	}

	a := &App{
		store:         store,
		bc:            newInMemoryBlockchain(4),
		mux:           http.NewServeMux(),
		blockchainSvc: blockchain.NewService(),
	}

	a.registerRoutes()
	return a
}

func (a *App) registerRoutes() {
	a.mux.HandleFunc("/blockchain/wallet/status", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		writeJSON(w, http.StatusOK, WalletStatusResponse{
			IsConnected: a.walletConnected,
			Address:     a.walletAddress,
			Timestamp:   time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/wallet/connect", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		if !a.walletConnected {
			a.walletConnected = true
			a.walletAddress = pseudoAddress(time.Now().UTC().Format(time.RFC3339Nano))
		}

		writeJSON(w, http.StatusOK, WalletConnectResponse{
			Success:   true,
			Address:   a.walletAddress,
			Message:   "Wallet connected successfully",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/wallet/disconnect", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		a.walletConnected = false
		a.walletAddress = ""
		writeJSON(w, http.StatusOK, map[string]any{
			"success":   true,
			"message":   "Wallet disconnected",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/wallet/balance", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if !a.walletConnected {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "wallet not connected"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"success":   true,
			"address":   a.walletAddress,
			"balance":   "0.00",
			"unit":      "ETH",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/gas-price", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"success":   true,
			"gasPrice":  "0.00",
			"unit":      "gwei",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/transactions/send", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		var req SendTransactionRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		tx := ChainTx{
			From:      req.From,
			To:        req.To,
			Amount:    req.Amount,
			CreatedAt: now.Format(time.RFC3339Nano),
		}
		tx.TxHash = "0x" + hashTx(tx)
		a.bc.addPendingTx(tx)
		writeJSON(w, http.StatusOK, SendTransactionResponse{
			Success:         true,
			TransactionHash: tx.TxHash,
			Message:         "Transaction submitted",
			Timestamp:       now.Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/chain", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		chain, pending := a.bc.snapshot()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":    true,
			"chain":      chain,
			"pending":    pending,
			"length":     len(chain),
			"difficulty": a.bc.difficulty,
		})
	}))

	a.mux.HandleFunc("/blockchain/mine", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		block, ok := a.bc.minePendingTxs()
		if !ok {
			writeJSON(w, http.StatusBadRequest, map[string]any{"success": false, "message": "no pending transactions"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"success": true, "block": block})
	}))

	a.mux.HandleFunc("/blockchain/validate", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		ok, reason := a.bc.validate()
		writeJSON(w, http.StatusOK, map[string]any{"success": true, "isValid": ok, "reason": reason})
	}))

	a.mux.HandleFunc("/blockchain/tamper", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var body struct {
			Index int `json:"index"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body.Index == 0 {
			body.Index = 1
		}
		ok := a.bc.tamperBlock(body.Index)
		if !ok {
			writeJSON(w, http.StatusBadRequest, map[string]any{"success": false, "message": "invalid index"})
			return
		}
		valid, reason := a.bc.validate()
		writeJSON(w, http.StatusOK, map[string]any{"success": true, "tamperedIndex": body.Index, "isValid": valid, "reason": reason})
	}))

	a.mux.HandleFunc("/blockchain/transactions/", withCORS(func(w http.ResponseWriter, r *http.Request) {
		txHash := strings.TrimPrefix(r.URL.Path, "/blockchain/transactions/")
		if txHash == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"success":   true,
			"txHash":    txHash,
			"confirmed": true,
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/yield-token", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req TokenizeYieldRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"transactionHash": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
			"tokenId":         "1",
			"message":         "Yield token created",
			"timestamp":       now.Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/token-info/", withCORS(func(w http.ResponseWriter, r *http.Request) {
		tokenId := strings.TrimPrefix(r.URL.Path, "/blockchain/token-info/")
		if tokenId == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"success":        true,
			"tokenId":        tokenId,
			"farmerId":       "FARMER_001",
			"cropType":       "Corn",
			"predictedYield": 0.0,
			"actualYield":    0.0,
			"harvestDate":    time.Now().UTC().Format(time.RFC3339),
			"currentPhase":   "predicted",
			"isActive":       true,
		})
	}))

	a.mux.HandleFunc("/blockchain/advanced/tokenize", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req AdvancedTokenizeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"tokenId":         "1",
			"farmerId":        req.FarmerId,
			"cropType":        req.CropType,
			"predictedYield":  req.PredictedYield,
			"harvestDate":     req.HarvestDate,
			"currentPhase":    "predicted",
			"insurancePolicy": map[string]any{"success": true, "tier": req.InsuranceTier},
			"transactionHash": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
		})
	}))

	a.mux.HandleFunc("/blockchain/advanced/transfer", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req TransferTokensRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			resp := response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()})
			writeJSON(w, response.HTTPStatusForCode("VALIDATION_ERROR"), resp)
			return
		}

		transferReq := blockchain.TransferRequest{
			TokenID:     req.TokenId,
			FromAddress: "0x" + strings.ToLower(fmt.Sprintf("%x", time.Now().UnixNano())), // mock from address
			ToAddress:   req.ToAddress,
			Amount:      fmt.Sprintf("%g", req.Amount),
		}
		ctx := context.Background()
		result, berr := a.blockchainSvc.Transfer(ctx, transferReq)
		if berr != nil {
			resp := response.NewError(berr.Code, berr.Message, berr.Details)
			writeJSON(w, response.HTTPStatusForCode(berr.Code), resp)
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"tokenId":         result.TokenID,
			"toAddress":       result.To,
			"amount":          result.Amount,
			"transactionHash": result.TxID,
			"phase":           string(result.Phase),
			"transferId":      result.TransferID,
			"timestamp":       time.Now().UTC().Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/tests/run", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		now := time.Now().UTC().Format(time.RFC3339)
		valid, reason := a.bc.validate()
		writeJSON(w, http.StatusOK, map[string]any{
			"initialize":           map[string]any{"success": true, "message": "Backend ready", "timestamp": now},
			"wallet_connection":    map[string]any{"success": true, "message": "Wallet simulated", "address": a.walletAddress, "timestamp": now},
			"balance_query":        map[string]any{"success": true, "message": "Balance simulated", "balance": "0.00", "timestamp": now},
			"gas_price":            map[string]any{"success": true, "message": "Gas price simulated", "gasPrice": "0.00", "timestamp": now},
			"contract_interaction": map[string]any{"success": true, "message": "Contract simulated", "timestamp": now},
			"chain_validation":     map[string]any{"success": true, "isValid": valid, "reason": reason, "message": "Chain validation completed", "timestamp": now},
		})
	}))

	a.mux.HandleFunc("/blockchain/insurance/policy", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		var req InsurancePolicyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"policyId":        "POL_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
			"tokenId":         req.TokenId,
			"farmerId":        req.FarmerId,
			"predictedYield":  req.PredictedYield,
			"tier":            req.Tier,
			"coverageRate":    0.6,
			"premium":         0.0,
			"insuredAmount":   0.0,
			"transactionHash": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
			"timestamp":       now.Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/yield/process", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		var req ProcessYieldRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"tokenId":         req.TokenId,
			"actualYield":     req.ActualYield,
			"oracleReport":    map[string]any{"isVerified": true, "confidence": 0.9},
			"transactionHash": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
			"timestamp":       now.Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/insurance/claim", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		var req InsuranceClaimRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
			return
		}
		now := time.Now().UTC()
		writeJSON(w, http.StatusOK, map[string]any{
			"success":         true,
			"tokenId":         req.TokenId,
			"policyId":        req.PolicyIdHint,
			"claimAmount":     req.Discrepancy,
			"transactionHash": "TX_" + strings.ReplaceAll(now.Format("20060102_150405.000"), ".", "_"),
			"timestamp":       now.Format(time.RFC3339),
		})
	}))

	a.mux.HandleFunc("/blockchain/assets", withCORS(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodOptions:
			w.WriteHeader(http.StatusNoContent)
			return
		case http.MethodGet:
			farmerId := r.URL.Query().Get("farmerId")
			if farmerId == "" {
				writeJSON(w, http.StatusBadRequest, map[string]any{"message": "farmerId is required"})
				return
			}
			assets, _ := a.store.ListAssetsByFarmer(farmerId)
			writeJSON(w, http.StatusOK, assets)
			return
		case http.MethodPost:
			var asset YieldAsset
			if err := json.NewDecoder(r.Body).Decode(&asset); err != nil {
				writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
				return
			}
			created, err := a.store.CreateAsset(asset)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, map[string]any{"message": err.Error()})
				return
			}
			writeJSON(w, http.StatusCreated, created)
			return
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
	}))

	a.mux.HandleFunc("/blockchain/assets/", withCORS(func(w http.ResponseWriter, r *http.Request) {
		assetId := strings.TrimPrefix(r.URL.Path, "/blockchain/assets/")
		if assetId == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		switch r.Method {
		case http.MethodOptions:
			w.WriteHeader(http.StatusNoContent)
			return
		case http.MethodGet:
			asset, ok := a.store.GetAsset(assetId)
			if !ok {
				writeJSON(w, http.StatusNotFound, map[string]any{"message": "asset not found"})
				return
			}
			writeJSON(w, http.StatusOK, asset)
			return
		case http.MethodPut:
			var asset YieldAsset
			if err := json.NewDecoder(r.Body).Decode(&asset); err != nil {
				writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
				return
			}
			updated, ok, err := a.store.UpdateAsset(assetId, asset)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, map[string]any{"message": err.Error()})
				return
			}
			if !ok {
				writeJSON(w, http.StatusNotFound, map[string]any{"message": "asset not found"})
				return
			}
			writeJSON(w, http.StatusOK, updated)
			return
		case http.MethodDelete:
			ok := a.store.DeleteAsset(assetId)
			if !ok {
				writeJSON(w, http.StatusNotFound, map[string]any{"message": "asset not found"})
				return
			}
			w.WriteHeader(http.StatusNoContent)
			return
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
	}))

	a.mux.HandleFunc("/blockchain/portfolio/", withCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		path := strings.TrimPrefix(r.URL.Path, "/blockchain/portfolio/")
		parts := strings.Split(strings.Trim(path, "/"), "/")
		if len(parts) != 2 || parts[1] != "summary" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		farmerId := parts[0]
		if farmerId == "" {
			writeJSON(w, http.StatusBadRequest, map[string]any{"message": "farmerId is required"})
			return
		}

		summary, err := a.store.GetPortfolioSummary(farmerId)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"message": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, summary)
	}))

	a.mux.HandleFunc("/blockchain/trades", withCORS(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodOptions:
			w.WriteHeader(http.StatusNoContent)
			return
		case http.MethodPost:
			var req TradeRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeJSON(w, http.StatusBadRequest, map[string]any{"message": "invalid json"})
				return
			}
			res, err := a.store.ExecuteTrade(req)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, map[string]any{"message": err.Error()})
				return
			}
			writeJSON(w, http.StatusOK, res)
			return
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
	}))

	a.mux.HandleFunc("/blockchain/market/crop/", withCORS(func(w http.ResponseWriter, r *http.Request) {
		cropType := strings.TrimPrefix(r.URL.Path, "/blockchain/market/crop/")
		if cropType == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		switch r.Method {
		case http.MethodOptions:
			w.WriteHeader(http.StatusNoContent)
			return
		case http.MethodGet:
			data, err := a.store.GetMarketData(cropType)
			if err != nil {
				writeJSON(w, http.StatusInternalServerError, map[string]any{"message": err.Error()})
				return
			}
			writeJSON(w, http.StatusOK, data)
			return
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
	}))

	a.mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
	})
}

func (a *App) Handler() http.Handler {
	return a.mux
}

func Handler() http.Handler {
	return NewApp().Handler()
}

func Run() error {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}
	addr := ":" + port
	log.Printf("server listening on %s", addr)
	return http.ListenAndServe(addr, Handler())
}

func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		next(w, r)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	_ = enc.Encode(v)
}
