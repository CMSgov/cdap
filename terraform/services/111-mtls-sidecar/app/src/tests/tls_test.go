package tests

import (
	"crypto/tls"
	"os"
	"testing"

	tlsconfig "mtls-sidecar/internal/tls"
)

// check the config is built correctly when mTLS is enabled
func TestNewServerTLSConfigRequiresClientCert(t *testing.T) {
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

// checks one-way TLS mode — client cert should not be required
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

// check that a missing cert file returns a clear error
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

// check that GetCertificate successfully loads the cert/key pair from disk
func TestGetCertificateLoadsFromDisk(t *testing.T) {
	certFile, keyFile, caFile := writeTempCerts(t)

	cfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
		CertFile:          certFile,
		KeyFile:           keyFile,
		CAFile:            caFile,
		RequireClientCert: true,
	})
	if err != nil {
		t.Fatalf("building TLS config: %v", err)
	}

	// nil ClientHelloInfo is fine for unit tests — we just want to confirm
	// the cert loads without error
	cert, err := cfg.GetCertificate(nil)
	if err != nil {
		t.Fatalf("GetCertificate returned error: %v", err)
	}

	if cert == nil {
		t.Fatal("GetCertificate returned nil cert")
	}
}

// check that cert rotation failures are surfaced correctly —
// if the cert file disappears mid-rotation, GetCertificate should error
func TestGetCertificateFailsAfterFileRemoved(t *testing.T) {
	certFile, keyFile, caFile := writeTempCerts(t)

	cfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
		CertFile:          certFile,
		KeyFile:           keyFile,
		CAFile:            caFile,
		RequireClientCert: true,
	})
	if err != nil {
		t.Fatalf("building TLS config: %v", err)
	}

	// simulate a cert rotation failure by removing the cert file
	os.Remove(certFile)

	_, err = cfg.GetCertificate(nil)
	if err == nil {
		t.Error("expected error after cert file removed, got nil")
	}
}

// helpers

// generate a CA-signed server cert/key/CA and write them to temp files.
// temp files are cleaned up automatically after each test via t.Cleanup.
func writeTempCerts(t *testing.T) (certFile, keyFile, caFile string) {
	t.Helper()
	certs := generateTestCerts(t)
	certFile = writeTempFile(t, "cert*.pem", certs.ServerCert)
	keyFile  = writeTempFile(t, "key*.pem", certs.ServerKey)
	caFile   = writeTempFile(t, "ca*.pem", certs.CACert)
	return certFile, keyFile, caFile
}

func writeTempFile(t *testing.T, pattern string, data []byte) string {
	t.Helper()
	f, err := os.CreateTemp("", pattern)
	if err != nil {
		t.Fatalf("creating temp file: %v", err)
	}
	// register cleanup so temp files are always removed, even on test failure
	t.Cleanup(func() { os.Remove(f.Name()) })
	if _, err := f.Write(data); err != nil {
		t.Fatalf("writing temp file: %v", err)
	}
	f.Close()
	return f.Name()
}
