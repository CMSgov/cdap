package middleware

import (
    "log"
    "net/http"
)

// responseWriter wraps http.ResponseWriter so we can capture
// the status code written by the upstream handler
type responseWriter struct {
    http.ResponseWriter
    status int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}

// Logging wraps any http.Handler and logs each request and
// its response status code. In ECS/Fargate, stdout is
// automatically shipped to CloudWatch.
func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        wrapped := &responseWriter{ResponseWriter: w, status: http.StatusOK}
        next.ServeHTTP(wrapped, r)
        log.Printf("method=%s path=%s remote=%s status=%d",
            r.Method, r.URL.Path, r.RemoteAddr, wrapped.status)
    })
}
