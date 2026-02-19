package bcs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
)

type BCSService struct {
	client Client
}

func NewBCSService(client Client) *BCSService {
	return &BCSService{client: client}
}

func chaincodeName() string {
	cc := strings.TrimSpace(os.Getenv("BCS_CHAINCODE_NAME"))
	if cc == "" {
		cc = "agriyield"
	}
	return cc
}

func (s *BCSService) CreateYieldAsset(ctx context.Context, args CreateYieldAssetArgs) (string, error) {
	payload, _ := json.Marshal(args)
	resp, err := s.client.InvokeChaincode(ctx, []string{chaincodeName(), "CreateYieldAsset", string(payload)})
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
	resp, err := s.client.InvokeChaincode(ctx, []string{chaincodeName(), "TransferTokens", string(payload)})
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
	resp, err := s.client.InvokeChaincode(ctx, []string{chaincodeName(), "UpdateActualYield", string(payload)})
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
