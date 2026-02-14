package app

import (
	"fmt"

	"agrichain-server/internal/api"
	"agrichain-server/internal/config"
)

func Run() error {
	cfg := config.Load()
	addr := fmt.Sprintf(":%s", cfg.Port)
	s := api.NewServer(addr)
	return s.ListenAndServe()
}
