package blockchain

import (
	"context"

	"agrichain-server/internal/blockchain/bcs"
)

type BCSServiceAdapter struct {
	svc *bcs.BCSService
}

func NewBCSServiceAdapter(svc *bcs.BCSService) *BCSServiceAdapter {
	return &BCSServiceAdapter{svc: svc}
}

func (a *BCSServiceAdapter) CreateYieldAsset(ctx context.Context, req CreateYieldAssetRequest) (CreateYieldAssetResult, *Error) {
	args := bcs.CreateYieldAssetArgs{
		FarmerID:       req.FarmerID,
		CropType:       req.CropType,
		PredictedYield: req.PredictedYield,
		InsuranceTier:  req.InsuranceTier,
	}
	txID, err := a.svc.CreateYieldAsset(ctx, args)
	if err != nil {
		return CreateYieldAssetResult{}, &Error{Code: "BCS_ERROR", Message: err.Error(), Details: nil}
	}
	// The chaincode is expected to mint an asset/token and returns a tx id.
	return CreateYieldAssetResult{AssetID: "BCS_ASSET_" + txID, TxID: txID}, nil
}

func (a *BCSServiceAdapter) Transfer(ctx context.Context, req TransferRequest) (TransferResult, *Error) {
	// Phase enforcement is assumed to be done in chaincode; we only map to BCS call
	args := bcs.TransferTokensArgs{
		TokenID: req.TokenID,
		To:      req.ToAddress,
		Amount:  req.Amount,
		Phase:   string(PhasePredicted), // TODO: derive from token state
	}
	txID, err := a.svc.TransferTokens(ctx, args)
	if err != nil {
		return TransferResult{}, &Error{
			Code:    "BCS_ERROR",
			Message: err.Error(),
		}
	}
	return TransferResult{
		TransferID: "BCS_" + txID,
		TokenID:    req.TokenID,
		From:       req.FromAddress,
		To:         req.ToAddress,
		Amount:     req.Amount,
		Phase:      PhasePredicted, // TODO: derive from token state
		TxID:       txID,
		Status:     "SUBMITTED",
	}, nil
}

func (a *BCSServiceAdapter) GetTokenPhase(tokenID string) (TokenPhase, bool) {
	// Placeholder: in real implementation, query chaincode for token state
	return PhasePredicted, true
}

func (a *BCSServiceAdapter) ListTransfers(ctx context.Context, req ListTransfersRequest) (ListTransfersResult, *Error) {
	// TODO: Implement BCS chaincode query for transfer history
	return ListTransfersResult{
		Transfers: []TransferResult{},
		Total:     0,
		Limit:     req.Limit,
		Offset:    req.Offset,
	}, nil
}
