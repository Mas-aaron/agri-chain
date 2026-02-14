package handlers

import (
	"net/http"

	"agrichain-server/internal/api/response"
	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type MeHandler struct {
	db *sqlite.DB
}

func NewMeHandler(db *sqlite.DB) *MeHandler {
	return &MeHandler{db: db}
}

func (h *MeHandler) Register(rg *gin.RouterGroup) {
	rg.GET("/me", h.getMe)
}

func (h *MeHandler) getMe(c *gin.Context) {
	v, ok := c.Get("auth")
	if !ok {
		resp := response.NewError("UNAUTHORIZED", "not authenticated", nil)
		c.JSON(http.StatusUnauthorized, resp)
		return
	}
	ac, ok := v.(middleware.AuthContext)
	if !ok {
		resp := response.NewError("UNAUTHORIZED", "invalid auth context", nil)
		c.JSON(http.StatusUnauthorized, resp)
		return
	}
	kyc, err := h.db.GetKYCStatus(c.Request.Context(), ac.UID)
	if err != nil {
		resp := response.NewError("INTERNAL", "failed to load profile", map[string]any{"error": err.Error()})
		c.JSON(http.StatusInternalServerError, resp)
		return
	}

	c.JSON(http.StatusOK, map[string]any{
		"uid":        ac.UID,
		"email":      ac.Email,
		"roles":      ac.Roles,
		"kyc_status": kyc,
	})
}
