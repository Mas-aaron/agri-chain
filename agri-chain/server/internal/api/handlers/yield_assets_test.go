package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/blockchain"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

func TestYieldAssetsMintFromPrediction(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// Mock yield prediction service
	yieldSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/predict" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"predicted_yield": 123.45, "confidence": 0.87}`))
	}))
	defer yieldSrv.Close()

	db, err := sqlite.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer func() { _ = db.Close() }()
	if err := db.Migrate(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.SetKYCStatus(context.Background(), "U1", "approved"); err != nil {
		t.Fatalf("set kyc: %v", err)
	}

	r := gin.New()
	v1 := r.Group("/v1")
	v1.Use(func(c *gin.Context) {
		c.Set("auth", middleware.AuthContext{UID: "U1", Email: "u1@example.com", Roles: []string{"farmer"}})
		c.Next()
	})
	v1.Use(middleware.RequireAuth())

	farmer := v1.Group("", middleware.RequireAnyRole("farmer", "admin"), middleware.RequireKYCApproved(db))

	h := NewYieldAssetsHandler(db, blockchain.NewMockService(), yieldSrv.URL)
	h.RegisterV1(farmer)

	body := map[string]any{
		"cropType":             "Maize",
		"insuranceTier":        "basic",
		"region":               "north",
		"soil_type":            "clay",
		"rainfall_mm":          12.3,
		"temperature_celsius":  28.5,
		"fertilizer_used":      true,
		"irrigation_used":      false,
		"weather_condition":    "sunny",
		"days_to_harvest":      30,
	}
	b, _ := json.Marshal(body)

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/yield-assets/mint", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var resp map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp["assetId"] == "" || resp["txId"] == "" {
		t.Fatalf("expected assetId and txId, got: %v", resp)
	}
}
