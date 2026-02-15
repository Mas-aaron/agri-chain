package handlers

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"agrichain-server/internal/api/response"
	"agrichain-server/internal/storage/sqlite"

	"github.com/gin-gonic/gin"
)

type ContractsHandler struct {
	db *sqlite.DB
}

func NewContractsHandler(db *sqlite.DB) *ContractsHandler {
	return &ContractsHandler{db: db}
}

type contractCreateRequest struct {
	Crop         string  `json:"crop"`
	QuantityKg   float64 `json:"quantity_kg"`
	UnitPrice    float64 `json:"unit_price"`
	Currency     string  `json:"currency"`
	FarmerName   string  `json:"farmer_name"`
	EvidenceHash *string `json:"evidence_hash"`
}

type contractPurchaseRequest struct {
	BuyerName string `json:"buyer_name"`
}

type contractDeliverRequest struct {
	Actor string  `json:"actor"`
	Ref   *string `json:"ref"`
}

func (h *ContractsHandler) RegisterPublic(r *gin.Engine) {
	r.GET("/contracts", h.listContracts)
	r.POST("/contracts", h.createContract)
	r.POST("/contracts/:id/purchase", h.purchaseContract)
	r.POST("/contracts/:id/deliver", h.deliverContract)
	r.GET("/ledger", h.listLedger)
}

func (h *ContractsHandler) RegisterV1(rg *gin.RouterGroup) {
	rg.GET("/contracts", h.listContracts)
	rg.POST("/contracts", h.createContract)
	rg.POST("/contracts/:id/purchase", h.purchaseContract)
	rg.POST("/contracts/:id/deliver", h.deliverContract)
	rg.GET("/ledger", h.listLedger)
}

func (h *ContractsHandler) RegisterV1ReadOnly(rg *gin.RouterGroup) {
	rg.GET("/contracts", h.listContracts)
	rg.GET("/ledger", h.listLedger)
}

func (h *ContractsHandler) RegisterV1FarmerActions(rg *gin.RouterGroup) {
	rg.POST("/contracts", h.createContract)
	rg.POST("/contracts/:id/deliver", h.deliverContract)
}

func (h *ContractsHandler) RegisterV1BuyerActions(rg *gin.RouterGroup) {
	rg.POST("/contracts/:id/purchase", h.purchaseContract)
}

func (h *ContractsHandler) listContracts(c *gin.Context) {
	status := strings.TrimSpace(c.Query("status"))
	var rows *sql.Rows
	var err error
	if status != "" {
		rows, err = h.dbSQL().QueryContext(c.Request.Context(), `SELECT id, crop, quantity_kg, unit_price, currency, status, farmer_name, buyer_name, evidence_hash, created_at FROM contracts WHERE LOWER(status)=LOWER(?) ORDER BY created_at DESC`, status)
	} else {
		rows, err = h.dbSQL().QueryContext(c.Request.Context(), `SELECT id, crop, quantity_kg, unit_price, currency, status, farmer_name, buyer_name, evidence_hash, created_at FROM contracts ORDER BY created_at DESC`)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to list contracts", map[string]any{"error": err.Error()}))
		return
	}
	defer rows.Close()

	var out []map[string]any
	for rows.Next() {
		var (
			id, crop, currency, statusV, farmer, createdAt string
			qty, unit                                      float64
			buyer                                          sql.NullString
			evidence                                       sql.NullString
		)
		if err := rows.Scan(&id, &crop, &qty, &unit, &currency, &statusV, &farmer, &buyer, &evidence, &createdAt); err != nil {
			c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to read contracts", map[string]any{"error": err.Error()}))
			return
		}
		m := map[string]any{
			"id":          id,
			"crop":        crop,
			"quantity_kg": qty,
			"unit_price":  unit,
			"currency":    currency,
			"status":      statusV,
			"farmer_name": farmer,
			"created_at":  createdAt,
		}
		if buyer.Valid {
			m["buyer_name"] = buyer.String
		} else {
			m["buyer_name"] = nil
		}
		if evidence.Valid {
			m["evidence_hash"] = evidence.String
		} else {
			m["evidence_hash"] = nil
		}
		out = append(out, m)
	}
	c.JSON(http.StatusOK, out)
}

func (h *ContractsHandler) createContract(c *gin.Context) {
	var req contractCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	if req.QuantityKg <= 0 {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "quantity_kg must be > 0", nil))
		return
	}
	if req.UnitPrice <= 0 {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "unit_price must be > 0", nil))
		return
	}
	if strings.TrimSpace(req.FarmerName) == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "farmer_name is required", nil))
		return
	}
	if strings.TrimSpace(req.Crop) == "" {
		req.Crop = "Maize"
	}
	if strings.TrimSpace(req.Currency) == "" {
		req.Currency = "UGX"
	}

	contractID := "FH-" + randomHex(12)
	now := time.Now().UTC().Format(time.RFC3339Nano)

	meta := map[string]string{"crop": req.Crop, "currency": req.Currency}
	metaJSON, _ := json.Marshal(meta)
	eventID := "L-" + randomHex(12)

	tx, err := h.dbSQL().BeginTx(c.Request.Context(), nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to open transaction", map[string]any{"error": err.Error()}))
		return
	}
	defer func() { _ = tx.Rollback() }()

	_, err = tx.ExecContext(c.Request.Context(), `INSERT INTO contracts (id, crop, quantity_kg, unit_price, currency, status, farmer_name, buyer_name, evidence_hash, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
		contractID, req.Crop, req.QuantityKg, req.UnitPrice, req.Currency, "LISTED", strings.TrimSpace(req.FarmerName), nil, req.EvidenceHash, now, now)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create contract", map[string]any{"error": err.Error()}))
		return
	}
	_, err = tx.ExecContext(c.Request.Context(), `INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?,?,?,?,?,?)`,
		eventID, now, "MINT_AND_LIST", strings.TrimSpace(req.FarmerName), contractID, string(metaJSON))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create ledger event", map[string]any{"error": err.Error()}))
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to commit", map[string]any{"error": err.Error()}))
		return
	}

	c.JSON(http.StatusOK, map[string]any{
		"id":            contractID,
		"crop":          req.Crop,
		"quantity_kg":   req.QuantityKg,
		"unit_price":    req.UnitPrice,
		"currency":      req.Currency,
		"status":        "LISTED",
		"farmer_name":   strings.TrimSpace(req.FarmerName),
		"buyer_name":    nil,
		"evidence_hash": req.EvidenceHash,
		"created_at":    now,
	})
}

func (h *ContractsHandler) purchaseContract(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	var req contractPurchaseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	if strings.TrimSpace(req.BuyerName) == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "buyer_name is required", nil))
		return
	}
	buyer := strings.TrimSpace(req.BuyerName)
	now := time.Now().UTC().Format(time.RFC3339Nano)

	tx, err := h.dbSQL().BeginTx(c.Request.Context(), nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to open transaction", map[string]any{"error": err.Error()}))
		return
	}
	defer func() { _ = tx.Rollback() }()

	var statusV string
	err = tx.QueryRowContext(c.Request.Context(), `SELECT status FROM contracts WHERE id=?`, id).Scan(&statusV)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, response.NewError("NOT_FOUND", "Contract not found", nil))
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load contract", map[string]any{"error": err.Error()}))
		return
	}
	if strings.ToUpper(statusV) != "LISTED" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "Contract not purchasable", map[string]any{"status": statusV}))
		return
	}

	_, err = tx.ExecContext(c.Request.Context(), `UPDATE contracts SET status=?, buyer_name=?, updated_at=? WHERE id=?`, "PURCHASED", buyer, now, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to update contract", map[string]any{"error": err.Error()}))
		return
	}

	metaJSON, _ := json.Marshal(map[string]string{"status": "PURCHASED"})
	_, err = tx.ExecContext(c.Request.Context(), `INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?,?,?,?,?,?)`, "L-"+randomHex(12), now, "PURCHASE", buyer, id, string(metaJSON))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create ledger event", map[string]any{"error": err.Error()}))
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to commit", map[string]any{"error": err.Error()}))
		return
	}

	h.respondContractByID(c, id)
}

func (h *ContractsHandler) deliverContract(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	var req contractDeliverRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "invalid json", map[string]any{"error": err.Error()}))
		return
	}
	actor := strings.TrimSpace(req.Actor)
	if actor == "" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "actor is required", nil))
		return
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)

	tx, err := h.dbSQL().BeginTx(c.Request.Context(), nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to open transaction", map[string]any{"error": err.Error()}))
		return
	}
	defer func() { _ = tx.Rollback() }()

	var statusV string
	err = tx.QueryRowContext(c.Request.Context(), `SELECT status FROM contracts WHERE id=?`, id).Scan(&statusV)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, response.NewError("NOT_FOUND", "Contract not found", nil))
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load contract", map[string]any{"error": err.Error()}))
		return
	}
	if strings.ToUpper(statusV) != "PURCHASED" {
		c.JSON(http.StatusBadRequest, response.NewError("VALIDATION_ERROR", "Contract not deliverable", map[string]any{"status": statusV}))
		return
	}

	_, err = tx.ExecContext(c.Request.Context(), `UPDATE contracts SET status=?, updated_at=? WHERE id=?`, "DELIVERED", now, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to update contract", map[string]any{"error": err.Error()}))
		return
	}

	meta := map[string]string{"status": "DELIVERED"}
	if req.Ref != nil && strings.TrimSpace(*req.Ref) != "" {
		meta["ref"] = strings.TrimSpace(*req.Ref)
	}
	metaJSON, _ := json.Marshal(meta)
	_, err = tx.ExecContext(c.Request.Context(), `INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?,?,?,?,?,?)`, "L-"+randomHex(12), now, "DELIVERY_RECORDED", actor, id, string(metaJSON))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to create ledger event", map[string]any{"error": err.Error()}))
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to commit", map[string]any{"error": err.Error()}))
		return
	}

	h.respondContractByID(c, id)
}

func (h *ContractsHandler) respondContractByID(c *gin.Context, id string) {
	row := h.dbSQL().QueryRowContext(c.Request.Context(), `SELECT id, crop, quantity_kg, unit_price, currency, status, farmer_name, buyer_name, evidence_hash, created_at FROM contracts WHERE id=?`, id)
	var (
		cid, crop, currency, statusV, farmer, createdAt string
		qty, unit                                       float64
		buyer                                           sql.NullString
		evidence                                        sql.NullString
	)
	if err := row.Scan(&cid, &crop, &qty, &unit, &currency, &statusV, &farmer, &buyer, &evidence, &createdAt); err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, response.NewError("NOT_FOUND", "Contract not found", nil))
			return
		}
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to load contract", map[string]any{"error": err.Error()}))
		return
	}
	m := map[string]any{
		"id":          cid,
		"crop":        crop,
		"quantity_kg": qty,
		"unit_price":  unit,
		"currency":    currency,
		"status":      statusV,
		"farmer_name": farmer,
		"created_at":  createdAt,
	}
	if buyer.Valid {
		m["buyer_name"] = buyer.String
	} else {
		m["buyer_name"] = nil
	}
	if evidence.Valid {
		m["evidence_hash"] = evidence.String
	} else {
		m["evidence_hash"] = nil
	}
	c.JSON(http.StatusOK, m)
}

func (h *ContractsHandler) listLedger(c *gin.Context) {
	contractID := strings.TrimSpace(c.Query("contract_id"))
	limit := 100
	if l := strings.TrimSpace(c.Query("limit")); l != "" {
		if v, err := parseInt(l); err == nil {
			limit = v
		}
	}
	if limit < 1 {
		limit = 1
	}
	if limit > 500 {
		limit = 500
	}

	var rows *sql.Rows
	var err error
	if contractID != "" {
		rows, err = h.dbSQL().QueryContext(c.Request.Context(), `SELECT id, time, action, actor, contract_id, meta_json FROM ledger_events WHERE contract_id=? ORDER BY time DESC LIMIT ?`, contractID, limit)
	} else {
		rows, err = h.dbSQL().QueryContext(c.Request.Context(), `SELECT id, time, action, actor, contract_id, meta_json FROM ledger_events ORDER BY time DESC LIMIT ?`, limit)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to list ledger", map[string]any{"error": err.Error()}))
		return
	}
	defer rows.Close()

	var out []map[string]any
	for rows.Next() {
		var id, t, action, actor, cid, metaJSON string
		if err := rows.Scan(&id, &t, &action, &actor, &cid, &metaJSON); err != nil {
			c.JSON(http.StatusInternalServerError, response.NewError("INTERNAL", "failed to read ledger", map[string]any{"error": err.Error()}))
			return
		}
		meta := map[string]string{}
		var anyMap map[string]any
		if err := json.Unmarshal([]byte(metaJSON), &anyMap); err == nil {
			for k, v := range anyMap {
				meta[k] = strings.TrimSpace(toString(v))
			}
		}
		out = append(out, map[string]any{
			"id":          id,
			"time":        t,
			"action":      action,
			"actor":       actor,
			"contract_id": cid,
			"meta":        meta,
		})
	}
	c.JSON(http.StatusOK, out)
}

func (h *ContractsHandler) dbSQL() *sql.DB {
	return h.db.SQL()
}

// helpers

func randomHex(n int) string {
	if n <= 0 {
		return ""
	}
	// n is in hex chars; need n/2 bytes (rounded up)
	bytesLen := (n + 1) / 2
	b := make([]byte, bytesLen)
	_, _ = rand.Read(b)
	s := hex.EncodeToString(b)
	if len(s) > n {
		return s[:n]
	}
	return s
}

func parseInt(s string) (int, error) {
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)
	return n, err
}

func toString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	default:
		return fmt.Sprintf("%v", t)
	}
}
