package tests

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"net/url"
	"testing"

	"mtls-sidecar/internal/middleware"
	tlsconfig "mtls-sidecar/internal/tls"
)

// spin up a real mTLS server and check that a client presenting a valid
// cert signed by the CA is accepted and gets a response from the upstream
func TestMTLSHandshakeWithClientCert(t *testing.T) {
	certs := generateTestCerts(t)

	// write server cert/key/CA to temp files — proxy reads from disk on each handshake
	certFile := writeTempFile(t, "cert*.pem", certs.ServerCert)
	keyFile  := writeTempFile(t, "key*.pem", certs.ServerKey)
	caFile   := writeTempFile(t, "ca*.pem", certs.CACert)

	// create a fake upstream that the proxy will forward to
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	defer upstream.Close()

	upstreamURL, _ := url.Parse(upstream.URL)
	proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
	handler := middleware.Logging(proxy)

	// build the mTLS server config, RequireClientCert enforces two-way TLS
	serverTLSCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
		CertFile:          certFile,
		KeyFile:           keyFile,
		CAFile:            caFile,
		RequireClientCert: true,
	})
	if err != nil {
		t.Fatalf("building server TLS config: %v", err)
	}

	// start a real TLS listener on a random port
	ln, err := tls.Listen("tcp", "127.0.0.1:0", serverTLSCfg)
	if err != nil {
		t.Fatalf("starting TLS listener: %v", err)
	}
	defer ln.Close()

	// serve in background, the test client will connect below
	go http.Serve(ln, handler)

	// build the client TLS config, present a cert signed by the same CA
	clientCert, err := tls.X509KeyPair(certs.ClientCert, certs.ClientKey)
	if err != nil {
		t.Fatalf("loading client cert: %v", err)
	}

	caPool := buildCAPool(t, certs.CACert)

	clientTLSCfg := &tls.Config{
		Certificates: []tls.Certificate{clientCert},
		RootCAs:      caPool,
		ServerName:   "localhost",
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialTLS: func(network, addr string) (net.Conn, error) {
				return tls.Dial(network, ln.Addr().String(), clientTLSCfg)
			},
		},
	}

	resp, err := client.Get("https://" + ln.Addr().String() + "/health")
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	if string(body) != "ok" {
		t.Errorf("expected body 'ok', got %q", string(body))
	}
}

// check that a client without a cert is rejected when RequireClientCert is true
func TestMTLSHandshakeWithoutClientCert(t *testing.T) {
	certs := generateTestCerts(t)

	certFile := writeTempFile(t, "cert*.pem", certs.ServerCert)
	keyFile  := writeTempFile(t, "key*.pem", certs.ServerKey)
	caFile   := writeTempFile(t, "ca*.pem", certs.CACert)

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

	// client presents no cert — server should reject the handshake
	clientTLSCfg := &tls.Config{
		RootCAs:    buildCAPool(t, certs.CACert),
		ServerName: "localhost",
		// no Certificates field — no client cert presented
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialTLS: func(network, addr string) (net.Conn, error) {
				return tls.Dial(network, ln.Addr().String(), clientTLSCfg)
			},
		},
	}

	_, err = client.Get("https://" + ln.Addr().String() + "/")
	if err == nil {
		t.Error("expected TLS error for client without cert, got nil")
	}
}

// helpers

// parse PEM-encoded CA cert and return an x509.CertPool
// used by both server and client to establish trust
func buildCAPool(t *testing.T, caPEM []byte) *x509.CertPool {
	t.Helper()
	block, _ := pem.Decode(caPEM)
	if block == nil {
		t.Fatal("failed to decode CA PEM")
	}
	caCert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		t.Fatalf("parsing CA cert: %v", err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(caCert)
	return pool
}
