package middleware

import (
	"log"
	"net/http"
	"time"
)

// Logging wraps an http.Handler and logs each request.
// SECURITY: does not log request headers or bodies which may
// contain sensitive data.
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		// Safe to log — method, path, and duration only
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	})
}
