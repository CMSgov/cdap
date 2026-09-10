package tests

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"testing"
	"time"

	"mtls-sidecar/internal/acm"
)

func TestGetEnvOrDefault(t *testing.T) {
	os.Setenv("TEST_VAR_SET", "custom")
	defer os.Unsetenv("TEST_VAR_SET")

	if got := getEnvOrDefault("TEST_VAR_SET", "default"); got != "custom" {
		t.Errorf("expected %q, got %q", "custom", got)
	}

	os.Unsetenv("TEST_VAR_UNSET")
	if got := getEnvOrDefault("TEST_VAR_UNSET", "default"); got != "default" {
		t.Errorf("expected %q, got %q", "default", got)
	}
}

func TestGetEnvBoolOrDefault(t *testing.T) {
	os.Setenv("TEST_BOOL_TRUE", "true")
	defer os.Unsetenv("TEST_BOOL_TRUE")
	if !getEnvBoolOrDefault("TEST_BOOL_TRUE", false) {
		t.Error("expected true")
	}

	os.Setenv("TEST_BOOL_FALSE", "false")
	defer os.Unsetenv("TEST_BOOL_FALSE")
	if getEnvBoolOrDefault("TEST_BOOL_FALSE", true) {
		t.Error("expected false")
	}

	os.Unsetenv("TEST_BOOL_UNSET")
	if !getEnvBoolOrDefault("TEST_BOOL_UNSET", true) {
		t.Error("expected default true when unset")
	}
}

func TestRequireEnv_Set(t *testing.T) {
	os.Setenv("TEST_REQUIRED_VAR", "value")
	defer os.Unsetenv("TEST_REQUIRED_VAR")

	if got := requireEnv("TEST_REQUIRED_VAR"); got != "value" {
		t.Errorf("expected %q, got %q", "value", got)
	}
}

func TestAcquireCertificates_LocalCertsSkipsACM(t *testing.T) {
	os.Setenv("USE_LOCAL_CERTS", "true")
	defer os.Unsetenv("USE_LOCAL_CERTS")

	err := acquireCertificates(context.Background(), acm.CertPaths{})
	if err != nil {
		t.Fatalf("expected nil error when USE_LOCAL_CERTS=true, got %v", err)
	}
}

func TestStartHealthServer(t *testing.T) {
	// reserve a free port, then hand it to startHealthServer
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("finding free port: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()

	srv := startHealthServer(fmt.Sprintf("%d", port))
	defer srv.Close()

	var resp *http.Response
	for i := 0; i < 20; i++ {
		resp, err = http.Get(fmt.Sprintf("http://127.0.0.1:%d/health", port))
		if err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if err != nil {
		t.Fatalf("health server did not become ready: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestStartProxyServer(t *testing.T) {
	upstream, _ := url.Parse("http://localhost:8080")
	tlsCfg := &tls.Config{InsecureSkipVerify: true}

	srv, err := startProxyServer("127.0.0.1:0", upstream, tlsCfg)
	if err != nil {
		t.Fatalf("startProxyServer returned error: %v", err)
	}
	defer srv.Close()

	if srv.Addr != "127.0.0.1:0" {
		t.Errorf("expected configured addr, got %q", srv.Addr)
	}
}

func TestStartProxyServer_InvalidAddr(t *testing.T) {
	upstream, _ := url.Parse("http://localhost:8080")
	tlsCfg := &tls.Config{}

	_, err := startProxyServer("not-a-valid-address", upstream, tlsCfg)
	if err == nil {
		t.Error("expected error for invalid listen address, got nil")
	}
}
