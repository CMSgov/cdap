package selftest

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

// WaitAndVerifyMTLS retries the mTLS self-test until it passes or
// maxAttempts is exhausted. Handles the race between the server
// goroutine starting and the self-test running.
//
// In production: clientCertFile and clientKeyFile are the same as the server cert
// In local dev: clientCertFile and clientKeyFile are the dedicated client cert
//
// If this returns an error the caller should log.Fatalf — causing
// the container to exit and ECS to trigger a deployment rollback.
func WaitAndVerifyMTLS(
    addr, caFile string,
    clientCertFile, clientKeyFile string,
    serverName string,
    maxAttempts int,
    delay time.Duration,
) error {
    var lastErr error
    for i := 1; i <= maxAttempts; i++ {
        lastErr = verifyMTLS(addr, caFile, clientCertFile, clientKeyFile, serverName)
        if lastErr == nil {
            return nil
        }
        log.Printf("mTLS self-test attempt %d/%d failed: %v", i, maxAttempts, lastErr)
        if i < maxAttempts {
            time.Sleep(delay)
        }
    }
    return fmt.Errorf("mTLS self-test failed after %d attempts: %w", maxAttempts, lastErr)
}

func verifyMTLS(addr, caFile, clientCertFile, clientKeyFile, serverName string) error {
    caPEM, err := os.ReadFile(caFile)
    if err != nil {
        return fmt.Errorf("reading CA file: %w", err)
    }

    pool := x509.NewCertPool()
    if !pool.AppendCertsFromPEM(caPEM) {
        return fmt.Errorf("failed to parse CA cert")
    }

    clientCert, err := tls.LoadX509KeyPair(clientCertFile, clientKeyFile)
    if err != nil {
        return fmt.Errorf("loading client cert for self-test: %w", err)
    }

    tlsCfg := &tls.Config{
        RootCAs:      pool,
        Certificates: []tls.Certificate{clientCert},
    }

    // If a server name is provided, use it for hostname verification
    // instead of the connection address (localhost).
    // This allows the self-test to connect via loopback while still
    // verifying the cert chain is valid for the real domain.
    if serverName != "" {
        tlsCfg.ServerName = serverName
    }

    client := &http.Client{
        Timeout: 5 * time.Second,
        Transport: &http.Transport{
            TLSClientConfig: tlsCfg,
        },
    }

    resp, err := client.Get(fmt.Sprintf("https://%s/health", addr))
    if err != nil {
        // SECURITY: TLS handshake errors sanitized — avoid cert detail leaking
        return fmt.Errorf("mTLS connection failed (details redacted for security)")
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("unexpected status %d from mTLS health endpoint", resp.StatusCode)
    }

    return nil
}
