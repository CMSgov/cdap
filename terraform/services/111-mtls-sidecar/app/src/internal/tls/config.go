package tls

import (
    "crypto/tls"
    "crypto/x509"
    "fmt"
    "os"
)

// construct paths needed to build a TLS configuration
type Config struct {
    CertFile          string
    KeyFile           string
    CAFile            string
    RequireClientCert bool
}

// build a *tls.Config for an mTLS server
// call on every handshake
// returned config uses GetCertificate so that cert rotation
// will work without restarting the server.
func NewServerTLSConfig(cfg Config) (*tls.Config, error) {
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

    return &tls.Config{
        GetCertificate: func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
            // Load fresh from disk on every handshake, allows to continue through cert rotation
            cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
            if err != nil {
                return nil, fmt.Errorf("loading cert/key pair: %w", err)
            }
            return &cert, nil  // define cert inside closure
        },
        ClientAuth: clientAuth,
        ClientCAs:  caPool,
        MinVersion: tls.VersionTLS12,
    }, nil
}
