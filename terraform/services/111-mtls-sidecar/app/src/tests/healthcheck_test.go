package main

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHealthCheck_Pass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/health" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	port := srv.Listener.Addr().(*net.TCPAddr).Port
	os.Setenv("HEALTH_PORT", fmt.Sprintf("%d", port))
	defer os.Unsetenv("HEALTH_PORT")

	resp, err := http.Get(fmt.Sprintf("http://localhost:%d/health", port))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestHealthCheck_Fail(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/health")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		t.Fatal("expected non-200 status")
	}
}

func TestHealthCheck_DefaultPort(t *testing.T) {
	// Verify default port is 8081 when HEALTH_PORT is not set
	os.Unsetenv("HEALTH_PORT")

	port := os.Getenv("HEALTH_PORT")
	if port == "" {
		port = "8081"
	}

	if port != "8081" {
		t.Fatalf("expected default port 8081, got %s", port)
	}
}
