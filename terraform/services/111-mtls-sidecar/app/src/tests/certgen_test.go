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

// PEM-encoded cert material for a CA, server, and client
// used across TLS and mTLS tests to avoid regenerating certs per test
type testCerts struct {
    CACert     []byte // PEM
    ServerCert []byte // PEM
    ServerKey  []byte // PEM
    ClientCert []byte // PEM
    ClientKey  []byte // PEM
}

// create a CA, a server cert signed by the CA
// and a client cert signed by the CA — suitable for mTLS testing
// make certs valid for one hour and use ECDSA P-256
// used only in tests — not for production use

func generateTestCerts(t *testing.T) testCerts {
    t.Helper()

    // CA
    caKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        t.Fatalf("generating CA key: %v", err)
    }

    caTemplate := &x509.Certificate{
        SerialNumber:          big.NewInt(1),
        Subject:               pkix.Name{CommonName: "test-ca"},
        NotBefore:             time.Now().Add(-time.Hour),
        NotAfter:              time.Now().Add(time.Hour),
        IsCA:                  true,
        KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
        BasicConstraintsValid: true,
    }

    caDER, err := x509.CreateCertificate(rand.Reader, caTemplate, caTemplate, &caKey.PublicKey, caKey)
    if err != nil {
        t.Fatalf("creating CA cert: %v", err)
    }

	// parse back so we can use it to sign server and client certs
    caCert, err := x509.ParseCertificate(caDER)
    if err != nil {
        t.Fatalf("parsing CA cert: %v", err)
    }

    caPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caDER})

    // Server cert signed by CA
    serverKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        t.Fatalf("generating server key: %v", err)
    }

    serverTemplate := &x509.Certificate{
        SerialNumber: big.NewInt(2),
        Subject:      pkix.Name{CommonName: "localhost"},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(time.Hour),
        KeyUsage:     x509.KeyUsageDigitalSignature,
        ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
        DNSNames:     []string{"localhost"},
    }

    serverDER, err := x509.CreateCertificate(rand.Reader, serverTemplate, caCert, &serverKey.PublicKey, caKey)
    if err != nil {
        t.Fatalf("creating server cert: %v", err)
    }

    serverCertPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: serverDER})
    serverKeyDER, err := x509.MarshalECPrivateKey(serverKey)
    if err != nil {
        t.Fatalf("marshaling server key: %v", err)
    }
    serverKeyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: serverKeyDER})

    // Client cert signed by CA
    clientKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        t.Fatalf("generating client key: %v", err)
    }

    clientTemplate := &x509.Certificate{
        SerialNumber: big.NewInt(3),
        Subject:      pkix.Name{CommonName: "test-client"},
        NotBefore:    time.Now().Add(-time.Hour),
        NotAfter:     time.Now().Add(time.Hour),
        KeyUsage:     x509.KeyUsageDigitalSignature,
        ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth},
    }

    clientDER, err := x509.CreateCertificate(rand.Reader, clientTemplate, caCert, &clientKey.PublicKey, caKey)
    if err != nil {
        t.Fatalf("creating client cert: %v", err)
    }

    clientCertPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: clientDER})
    clientKeyDER, err := x509.MarshalECPrivateKey(clientKey)
    if err != nil {
        t.Fatalf("marshaling client key: %v", err)
    }
    clientKeyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: clientKeyDER})

    return testCerts{
        CACert:     caPEM,
        ServerCert: serverCertPEM,
        ServerKey:  serverKeyPEM,
        ClientCert: clientCertPEM,
        ClientKey:  clientKeyPEM,
    }
}
