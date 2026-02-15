package handlers

import (
	"bytes"
	"io"
	"net/http"
	"net/url"
	"time"

	"agrichain-server/internal/api/response"

	"github.com/gin-gonic/gin"
)

type PredictProxyHandler struct {
	mlBaseURL string
	client    *http.Client
}

func NewPredictProxyHandler(mlBaseURL string) *PredictProxyHandler {
	return &PredictProxyHandler{
		mlBaseURL: mlBaseURL,
		client:    &http.Client{Timeout: 12 * time.Second},
	}
}

func (h *PredictProxyHandler) RegisterPublic(r *gin.Engine) {
	r.POST("/predict", h.predict)
}

func (h *PredictProxyHandler) RegisterV1(rg *gin.RouterGroup) {
	rg.POST("/predict", h.predict)
}

func (h *PredictProxyHandler) predict(c *gin.Context) {
	base, err := url.Parse(h.mlBaseURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "invalid ML_BASE_URL", map[string]any{"error": err.Error()}))
		return
	}
	endpoint := base.ResolveReference(&url.URL{Path: "/predict"})

	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid request body", map[string]any{"error": err.Error()}))
		return
	}

	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodPost, endpoint.String(), bytes.NewReader(body))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create request", map[string]any{"error": err.Error()}))
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := h.client.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, response.NewError("UPSTREAM_UNAVAILABLE", "ML service unavailable", map[string]any{"error": err.Error()}))
		return
	}
	defer resp.Body.Close()

	payload, _ := io.ReadAll(resp.Body)
	c.Data(resp.StatusCode, "application/json", payload)
}
