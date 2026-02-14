package blockchain

import (
	"agrichain-server/internal/blockchain/bcs"
	"os"
	"strings"
)

func NewService() Service {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("BLOCKCHAIN_MODE")))
	switch mode {
	case "bcs":
		client := bcs.NewClient()
		bcsSvc := bcs.NewBCSService(client)
		return NewBCSServiceAdapter(bcsSvc)
	default:
		return NewMockService()
	}
}
