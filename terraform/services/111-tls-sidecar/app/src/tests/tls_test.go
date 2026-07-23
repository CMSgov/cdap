package tests

import (
    "crypto/tls"
    "os"
    "testing"

    tlsconfig "reverse-proxy/internal/tls"
)

// TestNewServerTLSConfigRequiresClientCert checks that the config
// is built correctly when mTLS is enabled
func TestNewServerTLSConfigRequiresClientCert(t *testing.T) {
    // Write temp cert files for testing
    certFile, keyFile, caFile := writeTempCerts(t)

    cfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CertFile:          certFile,
        KeyFile:           keyFile,
        CAFile:            caFile,
        RequireClientCert: true,
    })

    if err != nil {
        t.Fatalf("expected no error, got: %v", err)
    }

    if cfg.ClientAuth != tls.RequireAndVerifyClientCert {
        t.Errorf("expected RequireAndVerifyClientCert, got %v", cfg.ClientAuth)
    }

    if cfg.ClientCAs == nil {
        t.Error("expected ClientCAs pool to be set")
    }

    if cfg.MinVersion != tls.VersionTLS12 {
        t.Errorf("expected TLS 1.2 minimum, got %v", cfg.MinVersion)
    }
}

// TestNewServerTLSConfigNoClientCert checks one-way TLS mode
func TestNewServerTLSConfigNoClientCert(t *testing.T) {
    certFile, keyFile, caFile := writeTempCerts(t)

    cfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CertFile:          certFile,
        KeyFile:           keyFile,
        CAFile:            caFile,
        RequireClientCert: false,
    })

    if err != nil {
        t.Fatalf("expected no error, got: %v", err)
    }

    if cfg.ClientAuth != tls.NoClientCert {
        t.Errorf("expected NoClientCert, got %v", cfg.ClientAuth)
    }
}

// TestNewServerTLSConfigBadCertPath checks that a missing cert
// file returns a clear error
func TestNewServerTLSConfigBadCertPath(t *testing.T) {
    _, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CertFile:          "/nonexistent/cert.pem",
        KeyFile:           "/nonexistent/key.pem",
        CAFile:            "/nonexistent/ca.pem",
        RequireClientCert: true,
    })

    if err == nil {
        t.Error("expected error for missing cert files, got nil")
    }
}

// writeTempCerts generates a minimal self-signed cert/key/CA
// and writes them to temp files for use in tests.
// It registers cleanup so temp files are removed after each test.
func writeTempCerts(t *testing.T) (certFile, keyFile, caFile string) {
    t.Helper()

    // These are minimal test certs — not for production use
    // Generated with: openssl req -x509 -newkey rsa:2048 ...
    // For real tests you'd generate these programmatically
    // using crypto/x509 — we'll add that in a later step
    cert, key, ca := generateSelfSignedCert(t)

    certFile = writeTempFile(t, "cert*.pem", cert)
    keyFile  = writeTempFile(t, "key*.pem", key)
    caFile   = writeTempFile(t, "ca*.pem", ca)

    return certFile, keyFile, caFile
}

func writeTempFile(t *testing.T, pattern string, data []byte) string {
    t.Helper()
    f, err := os.CreateTemp("", pattern)
    if err != nil {
        t.Fatalf("creating temp file: %v", err)
    }
    t.Cleanup(func() { os.Remove(f.Name()) })
    if _, err := f.Write(data); err != nil {
        t.Fatalf("writing temp file: %v", err)
    }
    f.Close()
    return f.Name()
}
