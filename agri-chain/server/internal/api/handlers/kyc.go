package handlers

import (
	"net/http"
	"strings"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type KYCHandler struct {
	db *sqlite.DB
}

func NewKYCHandler(db *sqlite.DB) *KYCHandler {
	return &KYCHandler{db: db}
}

type kycStatusResponse struct {
	UID    string `json:"uid"`
	Status string `json:"status"`
}

type kycUpdatePayload struct {
	Status string `json:"status"`
}

func (h *KYCHandler) RegisterSelf(rg *gin.RouterGroup) {
	rg.GET("/kyc", h.getSelf)
}

func (h *KYCHandler) RegisterAdmin(rg *gin.RouterGroup) {
	rg.PUT("/admin/kyc/:uid", h.putForUser)
}

func (h *KYCHandler) getSelf(c *gin.Context) {
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

	status, err := h.db.GetKYCStatus(c.Request.Context(), ac.UID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load kyc status", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, kycStatusResponse{UID: ac.UID, Status: status})
}

func (h *KYCHandler) putForUser(c *gin.Context) {
	uid := strings.TrimSpace(c.Param("uid"))
	if uid == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "uid is required", nil))
		return
	}
	var payload kycUpdatePayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	payload.Status = strings.TrimSpace(payload.Status)
	if payload.Status == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "status is required", nil))
		return
	}
	if err := h.db.SetKYCStatus(c.Request.Context(), uid, payload.Status); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to update kyc status", map[string]any{"error": err.Error()}))
		return
	}
	c.JSON(http.StatusOK, kycStatusResponse{UID: uid, Status: payload.Status})
}
