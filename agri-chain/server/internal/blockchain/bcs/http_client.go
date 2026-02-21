package bcs

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type HTTPClient struct {
	endpoint  string
	accessKey string
	secretKey string
	client    *http.Client
}

func NewHTTPClientFromEnv() Client {
	endpoint := strings.TrimSpace(os.Getenv("BCS_ENDPOINT"))
	accessKey := strings.TrimSpace(os.Getenv("BCS_ACCESS_KEY"))
	secretKey := strings.TrimSpace(os.Getenv("BCS_SECRET_KEY"))
	return &HTTPClient{
		endpoint:  endpoint,
		accessKey: accessKey,
		secretKey: secretKey,
		client:    &http.Client{Timeout: 15 * time.Second},
	}
}

// InvokeChaincode performs a generic chaincode invocation.
//
// This implementation is intentionally simple and env-driven so you can adapt
// it to the exact Huawei BCS gateway shape for your tenant.
//
// Expected response: {"txId":"..."}
func (c *HTTPClient) InvokeChaincode(ctx context.Context, args []string) ([]byte, error) {
	if strings.TrimSpace(c.endpoint) == "" {
		return nil, fmt.Errorf("BCS_ENDPOINT is empty")
	}
	if len(args) < 2 {
		return nil, fmt.Errorf("insufficient args: %v", args)
	}

	payload := map[string]any{
		"chaincode": args[0],
		"function":  args[1],
		"args":      args[2:],
	}
	b, _ := json.Marshal(payload)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	// Common headers; adjust to Huawei BCS requirements in your deployment.
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if c.accessKey != "" {
		req.Header.Set("X-BCS-Access-Key", c.accessKey)
	}
	if c.secretKey != "" {
		req.Header.Set("X-BCS-Secret-Key", c.secretKey)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("bcs http %d: %s", resp.StatusCode, string(body))
	}
	return body, nil
}
