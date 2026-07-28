package tests

import (
    "crypto/ecdsa"
    "crypto/elliptic"
    "crypto/rand"
    "crypto/x509"
    "crypto/x509/pkix"
    "encoding/pem"
    "math/big"
    "testing"
    "time"
)

// generateSelfSignedCert creates a minimal self-signed cert/key pair
// and returns them as PEM-encoded bytes. Used only in tests.
func generateSelfSignedCert(t *testing.T) (certPEM, keyPEM, caPEM []byte) {
    t.Helper()

    // Generate a private key
    key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        t.Fatalf("generating key: %v", err)
    }

    // Build the cert template
    template := &x509.Certificate{
        SerialNumber: big.NewInt(1),
        Subject:      pkix.Name{CommonName: "test"},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(time.Hour),
        KeyUsage:     x509.KeyUsageDigitalSignature,
        ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
        IsCA:         true,
    }

    // Self-sign the cert
    certDER, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
    if err != nil {
        t.Fatalf("creating certificate: %v", err)
    }

    // Encode cert to PEM
    certPEM = pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certDER})

    // Encode key to PEM
    keyDER, err := x509.MarshalECPrivateKey(key)
    if err != nil {
        t.Fatalf("marshaling key: %v", err)
    }
    keyPEM = pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})

    // For tests, CA is the same as the cert (self-signed)
    caPEM = certPEM

    return certPEM, keyPEM, caPEM
}
