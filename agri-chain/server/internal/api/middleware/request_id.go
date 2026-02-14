package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"

	"github.com/gin-gonic/gin"
)

func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		rid := c.GetHeader("X-Request-Id")
		if rid == "" {
			b := make([]byte, 16)
			_, _ = rand.Read(b)
			rid = hex.EncodeToString(b)
		}
		c.Writer.Header().Set("X-Request-Id", rid)
		c.Set("request_id", rid)
		c.Next()
	}
}

func GetRequestID(r *http.Request) string {
	return r.Header.Get("X-Request-Id")
}
