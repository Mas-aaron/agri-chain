package middleware

import (
	"bytes"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type cachedResponse struct {
	status int
	headers http.Header
	body   []byte
	expiresAt time.Time
}

type IdempotencyStore struct {
	mu sync.RWMutex
	m  map[string]cachedResponse
	ttl time.Duration
}

func NewIdempotencyStore(ttl time.Duration) *IdempotencyStore {
	return &IdempotencyStore{m: map[string]cachedResponse{}, ttl: ttl}
}

func (s *IdempotencyStore) Get(key string) (cachedResponse, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	v, ok := s.m[key]
	if !ok {
		return cachedResponse{}, false
	}
	if time.Now().After(v.expiresAt) {
		return cachedResponse{}, false
	}
	return v, true
}

func (s *IdempotencyStore) Set(key string, resp cachedResponse) {
	s.mu.Lock()
	defer s.mu.Unlock()
	resp.expiresAt = time.Now().Add(s.ttl)
	s.m[key] = resp
}

type captureWriter struct {
	gin.ResponseWriter
	body bytes.Buffer
}

func (w *captureWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

func Idempotency(store *IdempotencyStore) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := c.GetHeader("Idempotency-Key")
		if key == "" {
			c.Next()
			return
		}

		if cached, ok := store.Get(key); ok {
			for k, vals := range cached.headers {
				for _, v := range vals {
					c.Writer.Header().Add(k, v)
				}
			}
			c.Status(cached.status)
			_, _ = c.Writer.Write(cached.body)
			c.Abort()
			return
		}

		// ensure request body can be read downstream multiple times
		if c.Request.Body != nil {
			buf, _ := io.ReadAll(c.Request.Body)
			c.Request.Body.Close()
			c.Request.Body = io.NopCloser(bytes.NewBuffer(buf))
		}

		cw := &captureWriter{ResponseWriter: c.Writer}
		c.Writer = cw

		c.Next()

		store.Set(key, cachedResponse{status: c.Writer.Status(), headers: c.Writer.Header().Clone(), body: cw.body.Bytes()})
	}
}
