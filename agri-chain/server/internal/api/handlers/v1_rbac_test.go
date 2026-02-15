package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

func TestV1ContractsRBAC(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, err := sqlite.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer func() { _ = db.Close() }()
	if err := db.Migrate(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Approve KYC for our test user so KYC enforcement doesn't block happy-path RBAC checks.
	if err := db.SetKYCStatus(context.Background(), "U1", "approved"); err != nil {
		t.Fatalf("set kyc: %v", err)
	}

	// Helper that builds a router with an injected auth context (uid + roles)
	// in the same Gin engine where RequireAuth runs.
	doAs := func(method, path string, body any, roles []string) *httptest.ResponseRecorder {
		r := gin.New()
		v1 := r.Group("/v1")
		v1.Use(func(c *gin.Context) {
			c.Set("auth", middleware.AuthContext{UID: "U1", Email: "u1@example.com", Roles: roles})
			c.Next()
		})
		v1.Use(middleware.RequireAuth())

		ch := NewContractsHandler(db)
		ch.RegisterV1ReadOnly(v1)
		{
			farmer := v1.Group("", middleware.RequireAnyRole("farmer", "admin"), middleware.RequireKYCApproved(db))
			ch.RegisterV1FarmerActions(farmer)
		}
		{
			buyer := v1.Group("", middleware.RequireAnyRole("bank", "investor", "admin"), middleware.RequireKYCApproved(db))
			ch.RegisterV1BuyerActions(buyer)
		}

		w := httptest.NewRecorder()
		var buf *bytes.Reader
		if body != nil {
			b, _ := json.Marshal(body)
			buf = bytes.NewReader(b)
		} else {
			buf = bytes.NewReader(nil)
		}
		req := httptest.NewRequest(method, path, buf)
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		r.ServeHTTP(w, req)
		return w
	}

	// Bank cannot create
	w := doAs(http.MethodPost, "/v1/contracts", map[string]any{
		"crop":        "Maize",
		"quantity_kg": 100,
		"unit_price":  2.5,
		"currency":    "UGX",
		"farmer_name": "Farmer A",
	}, []string{"bank"})
	if w.Code != http.StatusForbidden {
		t.Fatalf("bank create expected 403 got %d body=%s", w.Code, w.Body.String())
	}

	// Farmer can create
	w = doAs(http.MethodPost, "/v1/contracts", map[string]any{
		"crop":        "Maize",
		"quantity_kg": 100,
		"unit_price":  2.5,
		"currency":    "UGX",
		"farmer_name": "Farmer A",
	}, []string{"farmer"})
	if w.Code != http.StatusOK {
		t.Fatalf("farmer create expected 200 got %d body=%s", w.Code, w.Body.String())
	}
	var created map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &created)
	cid, _ := created["id"].(string)
	if cid == "" {
		t.Fatalf("expected contract id in response")
	}

	// Farmer cannot purchase
	w = doAs(http.MethodPost, "/v1/contracts/"+cid+"/purchase", map[string]any{"buyer_name": "Buyer B"}, []string{"farmer"})
	if w.Code != http.StatusForbidden {
		t.Fatalf("farmer purchase expected 403 got %d body=%s", w.Code, w.Body.String())
	}

	// Bank can purchase
	w = doAs(http.MethodPost, "/v1/contracts/"+cid+"/purchase", map[string]any{"buyer_name": "Buyer B"}, []string{"bank"})
	if w.Code != http.StatusOK {
		t.Fatalf("bank purchase expected 200 got %d body=%s", w.Code, w.Body.String())
	}

	// Farmer can deliver
	w = doAs(http.MethodPost, "/v1/contracts/"+cid+"/deliver", map[string]any{"actor": "Farmer A"}, []string{"farmer"})
	if w.Code != http.StatusOK {
		t.Fatalf("farmer deliver expected 200 got %d body=%s", w.Code, w.Body.String())
	}

	// KYC enforcement: pending KYC cannot purchase.
	// Create a fresh contract in CREATED state to avoid business-rule validation errors.
	if err := db.SetKYCStatus(context.Background(), "U1", "approved"); err != nil {
		t.Fatalf("set kyc approved (again): %v", err)
	}
	w = doAs(http.MethodPost, "/v1/contracts", map[string]any{
		"crop":        "Maize",
		"quantity_kg": 50,
		"unit_price":  2.0,
		"currency":    "UGX",
		"farmer_name": "Farmer A",
	}, []string{"farmer"})
	if w.Code != http.StatusOK {
		t.Fatalf("farmer create #2 expected 200 got %d body=%s", w.Code, w.Body.String())
	}
	var created2 map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &created2)
	cid2, _ := created2["id"].(string)
	if cid2 == "" {
		t.Fatalf("expected contract id in response (#2)")
	}
	if err := db.SetKYCStatus(context.Background(), "U1", "pending"); err != nil {
		t.Fatalf("set kyc pending: %v", err)
	}
	w = doAs(http.MethodPost, "/v1/contracts/"+cid2+"/purchase", map[string]any{"buyer_name": "Buyer C"}, []string{"bank"})
	if w.Code != http.StatusForbidden {
		t.Fatalf("pending kyc purchase expected 403 got %d body=%s", w.Code, w.Body.String())
	}
}
