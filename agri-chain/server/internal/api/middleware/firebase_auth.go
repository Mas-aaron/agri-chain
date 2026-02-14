package middleware

import (
	"net/http"
	"strings"

	"agrichain-server/internal/auth"
	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type AuthContext struct {
	UID   string
	Email string
	Roles []string
}

func FirebaseAuth(verifier *auth.FirebaseVerifier, db *sqlite.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if h == "" || !strings.HasPrefix(strings.ToLower(h), "bearer ") {
			resp := response.NewError("UNAUTHORIZED", "missing bearer token", nil)
			c.JSON(http.StatusUnauthorized, resp)
			c.Abort()
			return
		}
		tok := strings.TrimSpace(h[len("Bearer "):])
		ft, err := verifier.VerifyIDToken(c.Request.Context(), tok)
		if err != nil {
			resp := response.NewError("UNAUTHORIZED", "invalid token", map[string]any{"error": err.Error()})
			c.JSON(http.StatusUnauthorized, resp)
			c.Abort()
			return
		}

		email, _ := ft.Claims["email"].(string)
		_ = db.EnsureUser(c.Request.Context(), ft.UID, email)
		roles, err := db.GetUserRoles(c.Request.Context(), ft.UID)
		if err != nil {
			resp := response.NewError("INTERNAL", "failed to load roles", map[string]any{"error": err.Error()})
			c.JSON(http.StatusInternalServerError, resp)
			c.Abort()
			return
		}

		c.Set("auth", AuthContext{UID: ft.UID, Email: email, Roles: roles})
		c.Next()
	}
}

func RequireAnyRole(roles ...string) gin.HandlerFunc {
	allowed := map[string]struct{}{}
	for _, r := range roles {
		allowed[r] = struct{}{}
	}

	return func(c *gin.Context) {
		v, ok := c.Get("auth")
		if !ok {
			resp := response.NewError("UNAUTHORIZED", "not authenticated", nil)
			c.JSON(http.StatusUnauthorized, resp)
			c.Abort()
			return
		}
		ac, ok := v.(AuthContext)
		if !ok {
			resp := response.NewError("UNAUTHORIZED", "invalid auth context", nil)
			c.JSON(http.StatusUnauthorized, resp)
			c.Abort()
			return
		}
		for _, r := range ac.Roles {
			if _, ok := allowed[r]; ok {
				c.Next()
				return
			}
		}
		resp := response.NewError("FORBIDDEN", "insufficient role", map[string]any{"required": roles, "have": ac.Roles})
		c.JSON(http.StatusForbidden, resp)
		c.Abort()
	}
}
