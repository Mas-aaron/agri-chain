package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"agrichain-server/internal/app"
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

func main() {
	if err := app.Run(); err != nil {
		log.Fatal(err)
	}
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
