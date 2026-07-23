package main

import (
    "log"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"
)

func main() {
    upstream, err := url.Parse(getEnvOrDefault("UPSTREAM_URL", "http://localhost:8080"))
    if err != nil {
        log.Fatalf("failed to parse upstream URL: %v", err)
    }

    proxy := httputil.NewSingleHostReverseProxy(upstream)
    handler := loggingMiddleware(proxy)

    addr := ":" + getEnvOrDefault("LISTEN_PORT", "8443")
    log.Printf("proxy listening on %s, forwarding to %s", addr, upstream)

    if err := http.ListenAndServe(addr, handler); err != nil {
        log.Fatalf("server error: %v", err)
    }
}

func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Printf("method=%s path=%s remote=%s", r.Method, r.URL.Path, r.RemoteAddr)
        next.ServeHTTP(w, r)
    })
}

func getEnvOrDefault(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}
