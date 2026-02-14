package bcs

import (
	"encoding/json"
)

type CreateYieldAssetArgs struct {
	FarmerID       string  `json:"farmerId"`
	CropType       string  `json:"cropType"`
	PredictedYield float64 `json:"predictedYield"`
	InsuranceTier  string  `json:"insuranceTier"`
}

type TransferTokensArgs struct {
	TokenID string `json:"tokenId"`
	To      string `json:"to"`
	Amount  string `json:"amount"`
	Phase   string `json:"phase"`
}

type UpdateActualYieldArgs struct {
	TokenID     string  `json:"tokenId"`
	ActualYield float64 `json:"actualYield"`
	OracleCID   string  `json:"oracleCid"`
	Confidence  float64 `json:"confidence"`
}

func CreateYieldAssetArgsFromMap(m map[string]interface{}) (CreateYieldAssetArgs, error) {
	b, _ := json.Marshal(m)
	var args CreateYieldAssetArgs
	if err := json.Unmarshal(b, &args); err != nil {
		return args, err
	}
	return args, nil
}

func TransferTokensArgsFromMap(m map[string]interface{}) (TransferTokensArgs, error) {
	b, _ := json.Marshal(m)
	var args TransferTokensArgs
	if err := json.Unmarshal(b, &args); err != nil {
		return args, err
	}
	return args, nil
}

func UpdateActualYieldArgsFromMap(m map[string]interface{}) (UpdateActualYieldArgs, error) {
	b, _ := json.Marshal(m)
	var args UpdateActualYieldArgs
	if err := json.Unmarshal(b, &args); err != nil {
		return args, err
	}
	return args, nil
}
