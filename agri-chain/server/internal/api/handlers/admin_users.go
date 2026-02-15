package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type AdminUsersHandler struct {
	db *sqlite.DB
}

func NewAdminUsersHandler(db *sqlite.DB) *AdminUsersHandler {
	return &AdminUsersHandler{db: db}
}

func (h *AdminUsersHandler) Register(rg *gin.RouterGroup) {
	rg.GET("/admin/users", h.list)
}

func (h *AdminUsersHandler) list(c *gin.Context) {
	limit := 200
	if raw := strings.TrimSpace(c.Query("limit")); raw != "" {
		if v, err := strconv.Atoi(raw); err == nil {
			limit = v
		}
	}

	users, err := h.db.ListUsers(c.Request.Context(), limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to list users", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, map[string]any{"users": users})
}
