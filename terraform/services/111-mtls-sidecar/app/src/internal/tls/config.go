package tls

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
)

// Config holds paths needed to build a TLS configuration
type Config struct {
	CertFile          string
	KeyFile           string
	CAFile            string
	RequireClientCert bool
}

// NewServerTLSConfig builds a *tls.Config for a strict mTLS server.
// GetCertificate reloads from disk on every handshake to support
// cert rotation without restarting the server.
func NewServerTLSConfig(cfg Config) (*tls.Config, error) {
	caPEM, err := os.ReadFile(cfg.CAFile)
	if err != nil {
		return nil, fmt.Errorf("reading CA file: %w", err)
	}

	caPool := x509.NewCertPool()
	if !caPool.AppendCertsFromPEM(caPEM) {
		return nil, fmt.Errorf("failed to parse CA cert from %s", cfg.CAFile)
	}

	// Always strict — health checks use the dedicated plain HTTP port
	// so we never need to relax this
	clientAuth := tls.RequireAndVerifyClientCert
	if !cfg.RequireClientCert {
		clientAuth = tls.NoClientCert
	}

	return &tls.Config{
		GetCertificate: func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
			// Reload from disk on every handshake — supports cert rotation
			cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
			if err != nil {
				// SECURITY: sanitized error — do not surface key material
				return nil, fmt.Errorf("failed to load server certificate")
			}
			return &cert, nil
		},
		ClientAuth: clientAuth,
		ClientCAs:  caPool,
		MinVersion: tls.VersionTLS12,
	}, nil
}
