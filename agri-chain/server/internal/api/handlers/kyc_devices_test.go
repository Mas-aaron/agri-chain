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

func TestKYCAndDevicesEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, err := sqlite.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer func() { _ = db.Close() }()
	if err := db.Migrate(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Build router with auth injection.
	r := gin.New()
	v1 := r.Group("/v1")
	v1.Use(func(c *gin.Context) {
		rolesHdr := c.GetHeader("X-Test-Roles")
		roles := []string{}
		if rolesHdr != "" {
			_ = json.Unmarshal([]byte(rolesHdr), &roles)
		}
		c.Set("auth", middleware.AuthContext{UID: "U1", Email: "u1@example.com", Roles: roles})
		c.Next()
	})
	v1.Use(middleware.RequireAuth())

	NewKYCHandler(db).RegisterSelf(v1)
	NewDevicesHandler(db).Register(v1)
	admin := v1.Group("", middleware.RequireAnyRole("admin", "regulator"))
	NewKYCHandler(db).RegisterAdmin(admin)

	// Self KYC defaults pending.
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/kyc", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("get self kyc status=%d body=%s", w.Code, w.Body.String())
	}

	// Non-regulator cannot set KYC.
	w = httptest.NewRecorder()
	b, _ := json.Marshal(map[string]any{"status": "approved"})
	req = httptest.NewRequest(http.MethodPut, "/v1/admin/kyc/U1", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Fatalf("set kyc without role expected 403 got %d body=%s", w.Code, w.Body.String())
	}

	// Regulator can set KYC.
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPut, "/v1/admin/kyc/U1", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Test-Roles", `["regulator"]`)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("set kyc as regulator expected 200 got %d body=%s", w.Code, w.Body.String())
	}

	// Register device token.
	w = httptest.NewRecorder()
	b, _ = json.Marshal(map[string]any{"token": "T1", "platform": "android"})
	req = httptest.NewRequest(http.MethodPost, "/v1/devices", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("post device expected 200 got %d body=%s", w.Code, w.Body.String())
	}

	// List device tokens.
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/v1/devices", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("get devices expected 200 got %d body=%s", w.Code, w.Body.String())
	}
}
