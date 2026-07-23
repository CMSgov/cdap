package tests

import (
    "net/http"
    "net/http/httptest"
    "testing"

    "reverse-proxy/internal/middleware"
)

// TestLoggingMiddlewarePassesThrough checks that the middleware
// does not swallow the request -- the upstream handler still runs
func TestLoggingMiddlewarePassesThrough(t *testing.T) {
    // Create a simple upstream handler that writes a 200
    upstream := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte("hello"))
    })

    // Wrap it with our logging middleware
    handler := middleware.Logging(upstream)

    // httptest.NewRecorder() is a fake ResponseWriter we can inspect
    rec := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/", nil)

    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("expected status 200, got %d", rec.Code)
    }

    if rec.Body.String() != "hello" {
        t.Errorf("expected body 'hello', got %q", rec.Body.String())
    }
}

// TestLoggingMiddlewareCapturesStatus checks that a non-200
// status from upstream is correctly passed through
func TestLoggingMiddlewareCapturesStatus(t *testing.T) {
    upstream := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusNotFound)
    })

    handler := middleware.Logging(upstream)

    rec := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/missing", nil)

    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusNotFound {
        t.Errorf("expected status 404, got %d", rec.Code)
    }
}

// TestLoggingMiddlewareDefaultStatus checks that if the upstream
// never calls WriteHeader, we default to 200
func TestLoggingMiddlewareDefaultStatus(t *testing.T) {
    upstream := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Deliberately never calls WriteHeader -- Go defaults to 200
        _, _ = w.Write([]byte("implicit 200"))
    })

    handler := middleware.Logging(upstream)

    rec := httptest.NewRecorder()
    req := httptest.NewRequest(http.MethodGet, "/", nil)

    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("expected default status 200, got %d", rec.Code)
    }
}
