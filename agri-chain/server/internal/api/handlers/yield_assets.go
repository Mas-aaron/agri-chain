package handlers

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"agrichain-server/internal/api/middleware"
	"agrichain-server/internal/api/response"
	"agrichain-server/internal/blockchain"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type YieldAssetsHandler struct {
	db           *sqlite.DB
	bc           blockchain.Service
	yieldBaseURL string
	client       *http.Client
}

func NewYieldAssetsHandler(db *sqlite.DB, bc blockchain.Service, yieldBaseURL string) *YieldAssetsHandler {
	return &YieldAssetsHandler{
		db:           db,
		bc:           bc,
		yieldBaseURL: yieldBaseURL,
		client:       &http.Client{Timeout: 12 * time.Second},
	}
}

func (h *YieldAssetsHandler) RegisterV1(rg *gin.RouterGroup) {
	rg.POST("/yield-assets/mint", h.mintFromPrediction)
	rg.GET("/yield-assets", h.listMyYieldAssets)
	rg.GET("/yield-assets/:id", h.getMyYieldAsset)
}

func (h *YieldAssetsHandler) listMyYieldAssets(c *gin.Context) {
	v, _ := c.Get("auth")
	ac, _ := v.(middleware.AuthContext)

	rows, err := h.db.SQL().QueryContext(
		c.Request.Context(),
		`SELECT time, contract_id, meta_json FROM ledger_events WHERE action = ? AND actor = ? ORDER BY time DESC`,
		"YIELD_ASSET_MINT", ac.UID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to list yield assets", map[string]any{"error": err.Error()}))
		return
	}
	defer rows.Close()

	var out []map[string]any
	for rows.Next() {
		var (
			timeStr  string
			assetID  string
			metaJSON string
		)
		if err := rows.Scan(&timeStr, &assetID, &metaJSON); err != nil {
			c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to scan yield assets", map[string]any{"error": err.Error()}))
			return
		}

		meta := map[string]any{}
		_ = json.Unmarshal([]byte(metaJSON), &meta)

		cropType, _ := meta["cropType"].(string)
		insuranceTier, _ := meta["insuranceTier"].(string)
		predictedYield := toFloat64(meta["predictedYield"])
		confidence := toFloat64(meta["confidence"])

		out = append(out, map[string]any{
			"assetId":        assetID,
			"tokenId":        "",
			"farmerId":       ac.UID,
			"cropType":       cropType,
			"season":         0,
			"predictedYield": predictedYield,
			"confidence":     confidence,
			"tokenAmount":    predictedYield,
			"currentValue":   0,
			"status":         "PREDICTED",
			"createdAt":      timeStr,
			"updatedAt":      nil,
			"txId":           meta["txId"],
			"insuranceTier":  insuranceTier,
			"evidenceHash":   meta["evidenceHash"],
		})
	}
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to iterate yield assets", map[string]any{"error": err.Error()}))
		return
	}

	c.JSON(http.StatusOK, out)
}

func (h *YieldAssetsHandler) getMyYieldAsset(c *gin.Context) {
	v, _ := c.Get("auth")
	ac, _ := v.(middleware.AuthContext)
	assetID := strings.TrimSpace(c.Param("id"))
	if assetID == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "missing asset id", nil))
		return
	}

	var (
		timeStr  string
		metaJSON string
	)
	err := h.db.SQL().QueryRowContext(
		c.Request.Context(),
		`SELECT time, meta_json FROM ledger_events WHERE action = ? AND actor = ? AND contract_id = ? ORDER BY time DESC LIMIT 1`,
		"YIELD_ASSET_MINT", ac.UID, assetID,
	).Scan(&timeStr, &metaJSON)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, response.NewError("NOT_FOUND", "yield asset not found", nil))
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load yield asset", map[string]any{"error": err.Error()}))
		return
	}

	meta := map[string]any{}
	_ = json.Unmarshal([]byte(metaJSON), &meta)

	cropType, _ := meta["cropType"].(string)
	insuranceTier, _ := meta["insuranceTier"].(string)
	predictedYield := toFloat64(meta["predictedYield"])
	confidence := toFloat64(meta["confidence"])

	c.JSON(http.StatusOK, map[string]any{
		"assetId":        assetID,
		"tokenId":        "",
		"farmerId":       ac.UID,
		"cropType":       cropType,
		"season":         0,
		"predictedYield": predictedYield,
		"confidence":     confidence,
		"tokenAmount":    predictedYield,
		"currentValue":   0,
		"status":         "PREDICTED",
		"createdAt":      timeStr,
		"updatedAt":      nil,
		"txId":           meta["txId"],
		"insuranceTier":  insuranceTier,
		"evidenceHash":   meta["evidenceHash"],
	})
}

type yieldMintRequest struct {
	CropType      string `json:"cropType" binding:"required"`
	InsuranceTier string `json:"insuranceTier"`

	Region             string  `json:"region" binding:"required"`
	SoilType           string  `json:"soil_type" binding:"required"`
	RainfallMM         float64 `json:"rainfall_mm" binding:"required"`
	TemperatureCelsius float64 `json:"temperature_celsius" binding:"required"`
	FertilizerUsed     bool    `json:"fertilizer_used"`
	IrrigationUsed     bool    `json:"irrigation_used"`
	WeatherCondition   string  `json:"weather_condition" binding:"required"`
	DaysToHarvest      int     `json:"days_to_harvest" binding:"required"`
}

type yieldPredictResponse struct {
	PredictedYield any    `json:"predicted_yield"`
	Confidence     any    `json:"confidence"`
	Message        string `json:"message"`
}

func (h *YieldAssetsHandler) mintFromPrediction(c *gin.Context) {
	v, _ := c.Get("auth")
	ac, _ := v.(middleware.AuthContext)

	var req yieldMintRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid request body", map[string]any{"error": err.Error()}))
		return
	}

	base, err := url.Parse(h.yieldBaseURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "invalid YIELD_API_BASE_URL", map[string]any{"error": err.Error()}))
		return
	}
	endpoint := base.ResolveReference(&url.URL{Path: "/predict"})

	predictPayload := map[string]any{
		"region":              req.Region,
		"soil_type":           req.SoilType,
		"rainfall_mm":         req.RainfallMM,
		"temperature_celsius": req.TemperatureCelsius,
		"fertilizer_used":     req.FertilizerUsed,
		"irrigation_used":     req.IrrigationUsed,
		"weather_condition":   req.WeatherCondition,
		"days_to_harvest":     req.DaysToHarvest,
	}
	payloadBytes, _ := json.Marshal(predictPayload)

	upReq, err := http.NewRequestWithContext(c.Request.Context(), http.MethodPost, endpoint.String(), bytes.NewReader(payloadBytes))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create yield request", map[string]any{"error": err.Error()}))
		return
	}
	upReq.Header.Set("Content-Type", "application/json")
	upReq.Header.Set("Accept", "application/json")

	upResp, err := h.client.Do(upReq)
	if err != nil {
		c.JSON(http.StatusBadGateway, response.NewError("UPSTREAM_UNAVAILABLE", "yield prediction service unavailable", map[string]any{"error": err.Error()}))
		return
	}
	defer upResp.Body.Close()

	body, _ := io.ReadAll(upResp.Body)
	if upResp.StatusCode >= 400 {
		c.JSON(http.StatusBadGateway, response.NewError("UPSTREAM_ERROR", "yield prediction failed", map[string]any{"status": upResp.StatusCode, "body": string(body)}))
		return
	}

	var pred yieldPredictResponse
	if err := json.Unmarshal(body, &pred); err != nil {
		c.JSON(http.StatusBadGateway, response.NewError("UPSTREAM_ERROR", "invalid yield prediction response", map[string]any{"error": err.Error()}))
		return
	}

	predictedYield := toFloat64(pred.PredictedYield)
	confidence := toFloat64(pred.Confidence)
	if predictedYield <= 0 {
		c.JSON(http.StatusBadGateway, response.NewError("UPSTREAM_ERROR", "yield prediction returned invalid predicted_yield", map[string]any{"predicted_yield": pred.PredictedYield}))
		return
	}

	bcRes, berr := h.bc.CreateYieldAsset(c.Request.Context(), blockchain.CreateYieldAssetRequest{
		FarmerID:       ac.UID,
		CropType:       strings.TrimSpace(req.CropType),
		PredictedYield: predictedYield,
		InsuranceTier:  strings.TrimSpace(req.InsuranceTier),
	})
	if berr != nil {
		c.JSON(response.HTTPStatusForCode(berr.Code), response.NewError(berr.Code, berr.Message, berr.Details))
		return
	}

	now := time.Now().UTC().Format(time.RFC3339Nano)
	evidenceHash := sha256Hex(append(payloadBytes, body...))
	meta := map[string]any{
		"assetId":         bcRes.AssetID,
		"txId":            bcRes.TxID,
		"predictedYield":  predictedYield,
		"confidence":      confidence,
		"cropType":        req.CropType,
		"insuranceTier":   req.InsuranceTier,
		"yieldApiUrl":     endpoint.String(),
		"evidenceHash":    evidenceHash,
		"upstreamMessage": pred.Message,
	}
	metaJSON, _ := json.Marshal(meta)

	eventID := "EV_" + shortHash(evidenceHash+":"+now)
	_, err = h.db.SQL().ExecContext(c.Request.Context(), `INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?,?,?,?,?,?)`,
		eventID, now, "YIELD_ASSET_MINT", ac.UID, bcRes.AssetID, string(metaJSON))
	if err != nil {
		// If ledger insert fails, still return success with tx info; this is an audit log.
		if err != sql.ErrConnDone {
			c.JSON(http.StatusAccepted, map[string]any{
				"assetId":        bcRes.AssetID,
				"txId":           bcRes.TxID,
				"predictedYield": predictedYield,
				"confidence":     confidence,
				"ledgerWarning":  err.Error(),
			})
			return
		}
	}

	c.JSON(http.StatusCreated, map[string]any{
		"assetId":        bcRes.AssetID,
		"txId":           bcRes.TxID,
		"predictedYield": predictedYield,
		"confidence":     confidence,
		"evidenceHash":   evidenceHash,
	})
}

func sha256Hex(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

func shortHash(s string) string {
	sum := sha256.Sum256([]byte(s))
	h := hex.EncodeToString(sum[:])
	return h[:12]
}

func toFloat64(v any) float64 {
	switch t := v.(type) {
	case nil:
		return 0
	case float64:
		return t
	case float32:
		return float64(t)
	case int:
		return float64(t)
	case int64:
		return float64(t)
	case json.Number:
		f, _ := t.Float64()
		return f
	case string:
		f, _ := json.Number(t).Float64()
		return f
	default:
		b, _ := json.Marshal(t)
		f, _ := json.Number(string(b)).Float64()
		return f
	}
}
