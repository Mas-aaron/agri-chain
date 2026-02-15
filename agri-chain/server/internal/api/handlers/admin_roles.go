package handlers

import (
	"net/http"
	"strings"

	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type AdminRolesHandler struct {
	db *sqlite.DB
}

func NewAdminRolesHandler(db *sqlite.DB) *AdminRolesHandler {
	return &AdminRolesHandler{db: db}
}

type rolesPayload struct {
	Roles []string `json:"roles"`
}

func (h *AdminRolesHandler) Register(rg *gin.RouterGroup) {
	rg.GET("/admin/users/:uid/roles", h.getRoles)
	rg.PUT("/admin/users/:uid/roles", h.putRoles)
}

func (h *AdminRolesHandler) getRoles(c *gin.Context) {
	uid := strings.TrimSpace(c.Param("uid"))
	if uid == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "uid is required", nil))
		return
	}
	roles, err := h.db.GetUserRoles(c.Request.Context(), uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load roles", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, rolesPayload{Roles: roles})
}

func (h *AdminRolesHandler) putRoles(c *gin.Context) {
	uid := strings.TrimSpace(c.Param("uid"))
	if uid == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "uid is required", nil))
		return
	}
	var payload rolesPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	if err := h.db.ReplaceUserRoles(c.Request.Context(), uid, payload.Roles); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to update roles", map[string]any{"error": err.Error()}))
		return
	}
	roles, err := h.db.GetUserRoles(c.Request.Context(), uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load roles", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, rolesPayload{Roles: roles})
}
