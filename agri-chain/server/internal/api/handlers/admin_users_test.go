package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

func TestAdminUsersListEndpoint(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, err := sqlite.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer func() { _ = db.Close() }()
	if err := db.Migrate(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Seed a couple users.
	_ = db.EnsureUser(context.Background(), "U1", "u1@example.com")
	_ = db.SetKYCStatus(context.Background(), "U1", "approved")
	_ = db.ReplaceUserRoles(context.Background(), "U1", []string{"farmer"})
	_ = db.EnsureUser(context.Background(), "U2", "u2@example.com")
	_ = db.ReplaceUserRoles(context.Background(), "U2", []string{"bank"})

	makeRouter := func(roles []string) *gin.Engine {
		r := gin.New()
		v1 := r.Group("/v1")
		v1.Use(func(c *gin.Context) {
			c.Set("auth", middleware.AuthContext{UID: "ADMIN", Email: "a@example.com", Roles: roles})
			c.Next()
		})
		v1.Use(middleware.RequireAuth())

		admin := v1.Group("", middleware.RequireAnyRole("admin"))
		NewAdminUsersHandler(db).Register(admin)
		return r
	}

	// Non-admin forbidden.
	{
		r := makeRouter([]string{"farmer"})
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/v1/admin/users", nil)
		r.ServeHTTP(w, req)
		if w.Code != http.StatusForbidden {
			t.Fatalf("expected 403 for non-admin got %d body=%s", w.Code, w.Body.String())
		}
	}

	// Admin allowed.
	{
		r := makeRouter([]string{"admin"})
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/v1/admin/users", nil)
		r.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("expected 200 for admin got %d body=%s", w.Code, w.Body.String())
		}
	}
}
