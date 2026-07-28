package main

import (
    "context"
    "crypto/tls"
    "log"
    "net"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"
    "os/signal"
    "syscall"

    "reverse-proxy/internal/acm"
    "reverse-proxy/internal/middleware"
    tlsconfig "reverse-proxy/internal/tls"
)

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    paths := acm.CertPaths{
        CertFile: getEnvOrDefault("TLS_CERT_FILE", "/etc/certs/cert.pem"),
        KeyFile:  getEnvOrDefault("TLS_KEY_FILE",  "/etc/certs/key.pem"),
        CAFile:   getEnvOrDefault("TLS_CA_FILE",   "/etc/certs/ca.pem"),
    }

    // In ECS: ACM_CERTIFICATE_ARN is injected via ECS Secrets from SSM.
    // Locally: USE_LOCAL_CERTS=true skips the ACM fetch entirely and
    // reads from the volume-mounted certs in docker-compose.
    if getEnvOrDefault("USE_LOCAL_CERTS", "false") != "true" {
        certARN := requireEnv("ACM_CERTIFICATE_ARN")

        acmClient, err := acm.New(ctx, certARN, paths)
        if err != nil {
            log.Fatalf("failed to create ACM client: %v", err)
        }

        if err := acmClient.FetchAndStore(ctx); err != nil {
            log.Fatalf("failed to fetch certificate from ACM: %v", err)
        }

        log.Println("certificate fetched from ACM and written to disk")
    } else {
        log.Println("USE_LOCAL_CERTS=true — skipping ACM fetch")
    }

    // Build TLS config — GetCertificate reads from disk on every
    // handshake so cert rotation writes are picked up automatically
    tlsCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CAFile:            paths.CAFile,
        RequireClientCert: getEnvBoolOrDefault("REQUIRE_CLIENT_CERT", true),
        GetCertificate: func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
            cert, err := tls.LoadX509KeyPair(paths.CertFile, paths.KeyFile)
            if err != nil {
                return nil, err
            }
            return &cert, nil
        },
    })
    if err != nil {
        log.Fatalf("failed to build TLS config: %v", err)
    }

    upstream, err := url.Parse(getEnvOrDefault("UPSTREAM_URL", "http://localhost:8080"))
    if err != nil {
        log.Fatalf("failed to parse upstream URL: %v", err)
    }

    proxy := httputil.NewSingleHostReverseProxy(upstream)
    handler := middleware.Logging(proxy)

    addr := ":" + getEnvOrDefault("LISTEN_PORT", "8443")

    srv := &http.Server{
        Addr:      addr,
        Handler:   handler,
        TLSConfig: tlsCfg,
    }

    ln, err := net.Listen("tcp", addr)
    if err != nil {
        log.Fatalf("failed to create listener: %v", err)
    }

    log.Printf("proxy listening on %s (mTLS), forwarding to %s", addr, upstream)

    go func() {
        if err := srv.ServeTLS(ln, "", ""); err != nil && err != http.ErrServerClosed {
            log.Fatalf("server error: %v", err)
        }
    }()

    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
    <-sigCh

    log.Println("shutting down...")
    cancel()
}

func requireEnv(key string) string {
    v := os.Getenv(key)
    if v == "" {
        log.Fatalf("required environment variable %q is not set", key)
    }
    return v
}

func getEnvOrDefault(key, def string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return def
}

func getEnvBoolOrDefault(key string, def bool) bool {
    if v := os.Getenv(key); v != "" {
        return v == "true"
    }
    return def
}
