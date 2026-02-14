package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

func BasicLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method
		c.Next()

		status := c.Writer.Status()
		lat := time.Since(start)
		rid, _ := c.Get("request_id")
		log.Printf("rid=%v method=%s path=%s status=%d latency=%s", rid, method, path, status, lat)
	}
}
