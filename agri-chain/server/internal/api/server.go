package api

import (
	"context"
	"log"
	"net/http"
	"time"

	"agrichain-server/internal/api/handlers"
	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/auth"
	"agrichain-server/internal/blockchain"
	"agrichain-server/internal/config"
	"agrichain-server/internal/legacy"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type Server struct {
	httpServer *http.Server
}

func NewServer(addr string) *Server {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.RequestID())
	r.Use(middleware.BasicLogger())
	r.Use(middleware.CORS())
	r.Use(middleware.Idempotency(middleware.NewIdempotencyStore(10 * time.Minute)))
	r.Use(middleware.Metrics())

	cfg := config.Load()
	db, err := sqlite.Open(cfg.SQLitePath)
	if err != nil {
		log.Fatalf("failed to open sqlite: %v", err)
	}
	if err := db.Migrate(context.Background()); err != nil {
		log.Fatalf("failed to run sqlite migrations: %v", err)
	}

	var verifier *auth.FirebaseVerifier
	if cfg.FirebaseCredentialsPath != "" {
		verifier, err = auth.NewFirebaseVerifier(context.Background(), cfg.FirebaseCredentialsPath)
		if err != nil {
			log.Fatalf("failed to init firebase verifier: %v", err)
		}
	}

	legacyHandler := legacy.Handler()
	blockchainSvc := blockchain.NewService()

	handlers.NewContractsHandler(db).RegisterPublic(r)
	handlers.NewPredictProxyHandler(cfg.MLBaseURL).RegisterPublic(r)

	v1 := r.Group("/v1")
	if verifier != nil {
		v1.Use(middleware.FirebaseAuth(verifier, db))
	}
	v1.Use(middleware.RequireAuth())
	handlers.NewMeHandler(db).Register(v1)
	handlers.NewKYCHandler(db).RegisterSelf(v1)
	handlers.NewDevicesHandler(db).Register(v1)
	{
		admin := v1.Group("", middleware.RequireAnyRole("admin"))
		handlers.NewAdminRolesHandler(db).Register(admin)
		handlers.NewAdminUsersHandler(db).Register(admin)
	}
	{
		reg := v1.Group("", middleware.RequireAnyRole("admin", "regulator"))
		handlers.NewKYCHandler(db).RegisterAdmin(reg)
	}
	ch := handlers.NewContractsHandler(db)
	ch.RegisterV1ReadOnly(v1)
	{
		farmer := v1.Group("", middleware.RequireAnyRole("farmer", "admin"), middleware.RequireKYCApproved(db))
		ch.RegisterV1FarmerActions(farmer)
		handlers.NewYieldAssetsHandler(db, blockchainSvc, cfg.YieldAPIBaseURL).RegisterV1(farmer)
	}
	{
		buyer := v1.Group("", middleware.RequireAnyRole("bank", "investor", "admin"), middleware.RequireKYCApproved(db))
		ch.RegisterV1BuyerActions(buyer)
	}
	handlers.NewPredictProxyHandler(cfg.MLBaseURL).RegisterV1(v1)
	handlers.NewTransferHandler(blockchainSvc).Register(v1)

	r.GET("/healthz", func(c *gin.Context) {
		legacyHandler.ServeHTTP(c.Writer, c.Request)
	})

	// Backward-compatible API surface consumed by Flutter.
	r.Any("/blockchain/*path", func(c *gin.Context) {
		legacyHandler.ServeHTTP(c.Writer, c.Request)
	})

	return &Server{httpServer: &http.Server{Addr: addr, Handler: r}}
}

func (s *Server) ListenAndServe() error {
	return s.httpServer.ListenAndServe()
}
