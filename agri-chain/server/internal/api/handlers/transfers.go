package handlers

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"agrichain-server/internal/api/response"
	"agrichain-server/internal/blockchain"

	"github.com/gin-gonic/gin"
)

type TransferHandler struct {
	svc blockchain.Service
}

func NewTransferHandler(svc blockchain.Service) *TransferHandler {
	return &TransferHandler{svc: svc}
}

func (h *TransferHandler) Register(rg *gin.RouterGroup) {
	rg.POST("/transfers", h.postTransfer)
	rg.GET("/transfers", h.getTransfers)
}

func (h *TransferHandler) getTransfers(c *gin.Context) {
	var req blockchain.ListTransfersRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		resp := response.NewError("VALIDATION_ERROR", "invalid query parameters", map[string]any{"error": err.Error()})
		c.JSON(http.StatusBadRequest, resp)
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	res, berr := h.svc.ListTransfers(ctx, req)
	if berr != nil {
		resp := response.NewError(berr.Code, berr.Message, berr.Details)
		c.JSON(response.HTTPStatusForCode(berr.Code), resp)
		return
	}

	// Simple ETag based on total and offset
	etag := fmt.Sprintf(`"%d-%d"`, res.Total, res.Offset)
	if match := c.GetHeader("If-None-Match"); match == etag {
		c.Status(http.StatusNotModified)
		return
	}

	c.Header("ETag", etag)
	c.Header("Cache-Control", "max-age=30, private")
	c.JSON(http.StatusOK, res)
}

func (h *TransferHandler) postTransfer(c *gin.Context) {
	var req blockchain.TransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		resp := response.NewError("VALIDATION_ERROR", "invalid request body", map[string]any{"error": err.Error()})
		c.JSON(http.StatusBadRequest, resp)
		return
	}
	req.IdempotencyKey = c.GetHeader("Idempotency-Key")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	res, berr := h.svc.Transfer(ctx, req)
	if berr != nil {
		resp := response.NewError(berr.Code, berr.Message, berr.Details)
		c.JSON(response.HTTPStatusForCode(berr.Code), resp)
		return
	}

	c.JSON(http.StatusAccepted, res)
}
