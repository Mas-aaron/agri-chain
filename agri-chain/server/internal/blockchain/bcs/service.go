package bcs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

type BCSService struct {
	client Client
}

func NewBCSService(client Client) *BCSService {
	return &BCSService{client: client}
}

func (s *BCSService) CreateYieldAsset(ctx context.Context, args CreateYieldAssetArgs) (string, error) {
	payload, _ := json.Marshal(args)
	resp, err := s.client.InvokeChaincode(ctx, []string{"agri_yield", "CreateYieldAsset", string(payload)})
	if err != nil {
		return "", err
	}
	var r struct {
		TxID string `json:"txId"`
	}
	if err := json.Unmarshal(resp, &r); err != nil {
		return "", fmt.Errorf("failed to unmarshal CreateYieldAsset response: %w", err)
	}
	if r.TxID == "" {
		return "", errors.New("CreateYieldAsset returned empty txId")
	}
	return r.TxID, nil
}

func (s *BCSService) TransferTokens(ctx context.Context, args TransferTokensArgs) (string, error) {
	payload, _ := json.Marshal(args)
	resp, err := s.client.InvokeChaincode(ctx, []string{"agri_yield", "TransferTokens", string(payload)})
	if err != nil {
		return "", err
	}
	var r struct {
		TxID string `json:"txId"`
	}
	if err := json.Unmarshal(resp, &r); err != nil {
		return "", fmt.Errorf("failed to unmarshal TransferTokens response: %w", err)
	}
	if r.TxID == "" {
		return "", errors.New("TransferTokens returned empty txId")
	}
	return r.TxID, nil
}

func (s *BCSService) UpdateActualYield(ctx context.Context, args UpdateActualYieldArgs) (string, error) {
	payload, _ := json.Marshal(args)
	resp, err := s.client.InvokeChaincode(ctx, []string{"agri_yield", "UpdateActualYield", string(payload)})
	if err != nil {
		return "", err
	}
	var r struct {
		TxID string `json:"txId"`
	}
	if err := json.Unmarshal(resp, &r); err != nil {
		return "", fmt.Errorf("failed to unmarshal UpdateActualYield response: %w", err)
	}
	if r.TxID == "" {
		return "", errors.New("UpdateActualYield returned empty txId")
	}
	return r.TxID, nil
}
