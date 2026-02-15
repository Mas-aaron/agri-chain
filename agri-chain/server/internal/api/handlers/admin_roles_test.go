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

func TestAdminRolesEndpoints(t *testing.T) {
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
	adminGroup := r.Group("/v1", fakeAuth([]string{"admin"}))
	NewAdminRolesHandler(db).Register(adminGroup)

	// PUT roles
	payload := map[string]any{"roles": []string{"farmer", "investor"}}
	b, _ := json.Marshal(payload)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPut, "/v1/admin/users/U1/roles", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("put status=%d body=%s", w.Code, w.Body.String())
	}

	// GET roles
	w = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/v1/admin/users/U1/roles", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("get status=%d body=%s", w.Code, w.Body.String())
	}
	var out map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if out["roles"] == nil {
		t.Fatalf("missing roles in response")
	}
}

func fakeAuth(roles []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("auth", middleware.AuthContext{UID: "U-ADMIN", Email: "a@example.com", Roles: roles})
		c.Next()
	}
}
