package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPredictProxy(t *testing.T) {
	gin.SetMode(gin.TestMode)

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/predict" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"predicted_yield":123.4,"confidence":null,"message":"ok"}`))
	}))
	defer upstream.Close()

	r := gin.New()
	NewPredictProxyHandler(upstream.URL).RegisterPublic(r)

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/predict", bytes.NewReader([]byte(`{"region":"x"}`)))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
	}
	if got := w.Body.String(); got == "" {
		t.Fatalf("empty body")
	}
}
