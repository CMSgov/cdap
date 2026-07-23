package tests

import (
    "net/http"
    "net/http/httptest"
    "net/http/httputil"
    "net/url"
    "testing"

    "reverse-proxy/internal/middleware"
)

// TestProxyForwardsToUpstream spins up a real test HTTP server
// as the upstream and checks that the proxy forwards correctly
func TestProxyForwardsToUpstream(t *testing.T) {
    // Create a fake upstream server
    upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte("upstream response"))
    }))
    defer upstream.Close()

    // Point the reverse proxy at our fake upstream
    upstreamURL, err := url.Parse(upstream.URL)
    if err != nil {
        t.Fatalf("failed to parse upstream URL: %v", err)
    }

    proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
    handler := middleware.Logging(proxy)

    // Create a fake request to the proxy
    rec := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/", nil)

    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("expected status 200, got %d", rec.Code)
    }

    if rec.Body.String() != "upstream response" {
        t.Errorf("expected 'upstream response', got %q", rec.Body.String())
    }
}

// TestProxyForwardsDifferentPaths checks that paths are
// forwarded to the upstream unchanged
func TestProxyForwardsDifferentPaths(t *testing.T) {
    upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Echo the path back so we can verify it arrived correctly
        _, _ = w.Write([]byte(r.URL.Path))
    }))
    defer upstream.Close()

    upstreamURL, _ := url.Parse(upstream.URL)
    proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
    handler := middleware.Logging(proxy)

    paths := []string{"/", "/foo", "/foo/bar", "/foo/bar/baz"}

    for _, path := range paths {
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, path, nil)

        handler.ServeHTTP(rec, req)

        if rec.Body.String() != path {
            t.Errorf("path %q: expected upstream to receive %q, got %q",
                path, path, rec.Body.String())
        }
    }
}
