package middleware

import (
    "log"
    "net/http"
)

// wrap http.ResponseWriter so we can capture
// the status code written by the upstream handler
type responseWriter struct {
    http.ResponseWriter
    status int
}

// capture status codes before pass thru
func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}

// wrap any http.Handler and log each request and
// its response status code. In ECS, stdout will be
// automatically shipped to CloudWatch.
// Risk mitigation: do not extend logging to include headers or body due to risk of printing certs
func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        wrapped := &responseWriter{ResponseWriter: w, status: http.StatusOK}
        next.ServeHTTP(wrapped, r)
        log.Printf("method=%s path=%s remote=%s status=%d",
            r.Method, r.URL.Path, r.RemoteAddr, wrapped.status)
    })
}
