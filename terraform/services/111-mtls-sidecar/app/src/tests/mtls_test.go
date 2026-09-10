package tests

import (
	"crypto/tls"
	"net/http"
	"testing"
	"time"

	"mtls-sidecar/internal/selftest"
	tlsconfig "mtls-sidecar/internal/tls"
)

// confirm WaitAndVerifyMTLS succeeds against a real mTLS server
// when given a valid client cert
func TestWaitAndVerifyMTLS_Success(t *testing.T) {
	certs := generateTestCerts(t)

	certFile := writeTempFile(t, "cert*.pem", certs.ServerCert)
	keyFile := writeTempFile(t, "key*.pem", certs.ServerKey)
	caFile := writeTempFile(t, "ca*.pem", certs.CACert)
	clientCertFile := writeTempFile(t, "client*.pem", certs.ClientCert)
	clientKeyFile := writeTempFile(t, "clientkey*.pem", certs.ClientKey)

	serverTLSCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
		CertFile:          certFile,
		KeyFile:           keyFile,
		CAFile:            caFile,
		RequireClientCert: true,
	})
	if err != nil {
		t.Fatalf("building server TLS config: %v", err)
	}

	ln, err := tls.Listen("tcp", "127.0.0.1:0", serverTLSCfg)
	if err != nil {
		t.Fatalf("starting TLS listener: %v", err)
	}
	defer ln.Close()

	go http.Serve(ln, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("ok"))
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))

	err = selftest.WaitAndVerifyMTLS(
		ln.Addr().String(),
		caFile,
		clientCertFile,
		clientKeyFile,
		"localhost",
		5,
		50*time.Millisecond,
	)
	if err != nil {
		t.Fatalf("expected self-test to pass, got error: %v", err)
	}
}

// confirm WaitAndVerifyMTLS fails (after retries) when the server
// requires a client cert but none is provided
func TestWaitAndVerifyMTLS_NoClientCert(t *testing.T) {
	certs := generateTestCerts(t)

	certFile := writeTempFile(t, "cert*.pem", certs.ServerCert)
	keyFile := writeTempFile(t, "key*.pem", certs.ServerKey)
	caFile := writeTempFile(t, "ca*.pem", certs.CACert)

	serverTLSCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
		CertFile:          certFile,
		KeyFile:           keyFile,
		CAFile:            caFile,
		RequireClientCert: true,
	})
	if err != nil {
		t.Fatalf("building server TLS config: %v", err)
	}

	ln, err := tls.Listen("tcp", "127.0.0.1:0", serverTLSCfg)
	if err != nil {
		t.Fatalf("starting TLS listener: %v", err)
	}
	defer ln.Close()

	go http.Serve(ln, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// empty cert/key file paths — no client cert presented
	err = selftest.WaitAndVerifyMTLS(
		ln.Addr().String(),
		caFile,
		"",
		"",
		"localhost",
		2, // keep attempts low — expected to fail every time
		10*time.Millisecond,
	)
	if err == nil {
		t.Error("expected self-test to fail without a client cert, got nil")
	}
}

// confirm a fast, clear failure when the CA file itself is missing
// should fail without ever attempting a connection
func TestWaitAndVerifyMTLS_BadCAFile(t *testing.T) {
	err := selftest.WaitAndVerifyMTLS(
		"127.0.0.1:1",
		"/nonexistent/ca.pem",
		"",
		"",
		"",
		2,
		10*time.Millisecond,
	)
	if err == nil {
		t.Error("expected error for missing CA file, got nil")
	}
}
