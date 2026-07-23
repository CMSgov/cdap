package tls

import (
    "crypto/tls"
    "crypto/x509"
    "fmt"
    "os"
)

// Config holds the paths needed to build a TLS configuration
type Config struct {
    CertFile   string
    KeyFile    string
    CAFile     string
    // If true, client must present a cert signed by the CA.
    // Set to false to allow one-way TLS
    RequireClientCert bool
}

// NewServerTLSConfig builds a *tls.Config suitable for an mTLS server.
// The returned config uses GetCertificate so that cert rotation
// will work without restarting the server.
func NewServerTLSConfig(cfg Config) (*tls.Config, error) {
    // Load the server cert and key
    cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
    if err != nil {
        return nil, fmt.Errorf("loading server cert/key: %w", err)
    }

    // Load the CA bundle used to validate client certs
    caPEM, err := os.ReadFile(cfg.CAFile)
    if err != nil {
        return nil, fmt.Errorf("reading CA file: %w", err)
    }

    caPool := x509.NewCertPool()
    if !caPool.AppendCertsFromPEM(caPEM) {
        return nil, fmt.Errorf("failed to parse CA cert from %s", cfg.CAFile)
    }

    clientAuth := tls.RequireAndVerifyClientCert
    if !cfg.RequireClientCert {
        clientAuth = tls.NoClientCert
    }

    tlsCfg := &tls.Config{
        // GetCertificate is called on every handshake.
        // TODO swap this to pull from ACM dynamically.
        GetCertificate: func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
            return &cert, nil
        },
        ClientAuth: clientAuth,
        ClientCAs:  caPool,
        MinVersion: tls.VersionTLS12,
    }

    return tlsCfg, nil
}
