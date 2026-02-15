package handlers

import (
	"net/http"
	"strings"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type DevicesHandler struct {
	db *sqlite.DB
}

func NewDevicesHandler(db *sqlite.DB) *DevicesHandler {
	return &DevicesHandler{db: db}
}

type deviceTokenPayload struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

type deviceTokensResponse struct {
	Tokens []string `json:"tokens"`
}

func (h *DevicesHandler) Register(rg *gin.RouterGroup) {
	rg.POST("/devices", h.postToken)
	rg.GET("/devices", h.getTokens)
}

func (h *DevicesHandler) postToken(c *gin.Context) {
	v, ok := c.Get("auth")
	if !ok {
		c.JSON(http.StatusUnauthorized, response.NewError("UNAUTHORIZED", "not authenticated", nil))
		return
	}
	ac, ok := v.(middleware.AuthContext)
	if !ok {
		c.JSON(http.StatusUnauthorized, response.NewError("UNAUTHORIZED", "invalid auth context", nil))
		return
	}

	var payload deviceTokenPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	payload.Token = strings.TrimSpace(payload.Token)
	payload.Platform = strings.TrimSpace(payload.Platform)
	if payload.Token == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "token is required", nil))
		return
	}

	if err := h.db.UpsertDeviceToken(c.Request.Context(), ac.UID, payload.Token, payload.Platform); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to save device token", map[string]any{"error": err.Error()}))
		return
	}

	c.JSON(http.StatusOK, map[string]any{"ok": true})
}

func (h *DevicesHandler) getTokens(c *gin.Context) {
	v, ok := c.Get("auth")
	if !ok {
		c.JSON(http.StatusUnauthorized, response.NewError("UNAUTHORIZED", "not authenticated", nil))
		return
	}
	ac, ok := v.(middleware.AuthContext)
	if !ok {
		c.JSON(http.StatusUnauthorized, response.NewError("UNAUTHORIZED", "invalid auth context", nil))
		return
	}

	tokens, err := h.db.ListDeviceTokens(c.Request.Context(), ac.UID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load device tokens", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, deviceTokensResponse{Tokens: tokens})
}
