package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

func TestContractsLifecycleAndLedger(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, err := sqlite.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer func() { _ = db.Close() }()
	if err := db.Migrate(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	r := gin.New()
	NewContractsHandler(db).RegisterPublic(r)

	// create
	createBody := map[string]any{
		"crop":        "Maize",
		"quantity_kg": 100.0,
		"unit_price":  2.5,
		"currency":    "UGX",
		"farmer_name": "Farmer A",
	}
	b, _ := json.Marshal(createBody)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/contracts", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("create status=%d body=%s", w.Code, w.Body.String())
	}
	var created map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &created)
	cid, _ := created["id"].(string)
	if cid == "" {
		t.Fatalf("missing id in create response")
	}

	// purchase
	purchaseBody := map[string]any{"buyer_name": "Buyer B"}
	b, _ = json.Marshal(purchaseBody)
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contracts/"+cid+"/purchase", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("purchase status=%d body=%s", w.Code, w.Body.String())
	}

	// deliver
	deliverBody := map[string]any{"actor": "Farmer A", "ref": "REF-1"}
	b, _ = json.Marshal(deliverBody)
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/contracts/"+cid+"/deliver", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("deliver status=%d body=%s", w.Code, w.Body.String())
	}

	// ledger filter
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/ledger?contract_id="+cid+"&limit=10", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("ledger status=%d body=%s", w.Code, w.Body.String())
	}
	var events []map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &events)
	if len(events) < 3 {
		t.Fatalf("expected >= 3 ledger events, got %d", len(events))
	}
}
