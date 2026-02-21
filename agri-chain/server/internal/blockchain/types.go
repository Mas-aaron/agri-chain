package blockchain

import "context"

type TokenPhase string

const (
	PhasePredicted  TokenPhase = "PREDICTED"
	PhaseHarvesting TokenPhase = "HARVESTING"
	PhaseSettled    TokenPhase = "SETTLED"
)

type ParticipantRole string

const (
	RoleFarmer    ParticipantRole = "FARMER"
	RoleBank      ParticipantRole = "BANK"
	RoleTrader    ParticipantRole = "TRADER"
	RoleProcessor ParticipantRole = "PROCESSOR"
	RoleWarehouse ParticipantRole = "WAREHOUSE"
	RoleDelivery  ParticipantRole = "DELIVERY"
)

type TransferRequest struct {
	TokenID        string          `json:"tokenId" binding:"required"`
	FromAddress    string          `json:"from" binding:"required"`
	ToAddress      string          `json:"to" binding:"required"`
	Amount         string          `json:"amount" binding:"required"`
	IdempotencyKey string          `json:"-"`
	FiatValueUSD   float64         `json:"fiatValueUsd,omitempty"`
	ToRoleHint     ParticipantRole `json:"toRoleHint,omitempty"`
}

type TransferResult struct {
	TransferID string     `json:"transferId"`
	TokenID    string     `json:"tokenId"`
	From       string     `json:"from"`
	To         string     `json:"to"`
	Amount     string     `json:"amount"`
	Phase      TokenPhase `json:"phase"`
	TxID       string     `json:"txId"`
	Status     string     `json:"status"`
}

type ListTransfersRequest struct {
	TokenID     string `json:"tokenId,omitempty"`
	FromAddress string `json:"from,omitempty"`
	ToAddress   string `json:"to,omitempty"`
	Limit       int    `json:"limit,omitempty"`
	Offset      int    `json:"offset,omitempty"`
}

type ListTransfersResult struct {
	Transfers []TransferResult `json:"transfers"`
	Total     int              `json:"total"`
	Limit     int              `json:"limit"`
	Offset    int              `json:"offset"`
}

type CreateYieldAssetRequest struct {
	FarmerID       string  `json:"farmerId"`
	CropType       string  `json:"cropType"`
	PredictedYield float64 `json:"predictedYield"`
	InsuranceTier  string  `json:"insuranceTier"`
}

type CreateYieldAssetResult struct {
	AssetID string `json:"assetId"`
	TxID    string `json:"txId"`
}

type Service interface {
	CreateYieldAsset(ctx context.Context, req CreateYieldAssetRequest) (CreateYieldAssetResult, *Error)
	Transfer(ctx context.Context, req TransferRequest) (TransferResult, *Error)
	GetTokenPhase(tokenID string) (TokenPhase, bool)
	ListTransfers(ctx context.Context, req ListTransfersRequest) (ListTransfersResult, *Error)
}

type Error struct {
	Code    string
	Message string
	Details map[string]any
}
