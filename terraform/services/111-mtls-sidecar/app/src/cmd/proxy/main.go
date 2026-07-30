package main

import (
    "context"
    "log"
    "net"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"
    "os/signal"
    "path/filepath"
    "syscall"

    "mtls-sidecar/internal/acm"
    "mtls-sidecar/internal/middleware"
    tlsconfig "mtls-sidecar/internal/tls"
)

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    paths := acm.CertPaths{
        CertFile: getEnvOrDefault("TLS_CERT_FILE", "/tmp/certs/cert.pem"),
        KeyFile:  getEnvOrDefault("TLS_KEY_FILE",  "/tmp/certs/key.pem"),
        CAFile:   getEnvOrDefault("TLS_CA_FILE",   "/tmp/certs/ca.pem"),
    }

    if getEnvOrDefault("USE_LOCAL_CERTS", "false") != "true" {
        certARN := requireEnv("ACM_CERTIFICATE_ARN")
        client, err := acm.New(ctx, certARN, paths)
        if err != nil {
            log.Fatalf("failed to create ACM client: %v", err)
        }
        if err := ensureCertDir(paths.CertFile); err != nil {
            log.Fatalf("failed to create cert directory: %v", err)
        }
        if err := client.FetchAndStore(ctx); err != nil {
            log.Fatalf("failed to fetch certificate: %v", err)
        }
        log.Println("certificate fetched from ACM")
    } else {
        log.Println("USE_LOCAL_CERTS=true — skipping ACM fetch")
    }

    tlsCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CertFile:          paths.CertFile,
        KeyFile:           paths.KeyFile,
        CAFile:            paths.CAFile,
        RequireClientCert: getEnvBoolOrDefault("REQUIRE_CLIENT_CERT", true),
    })
    if err != nil {
        log.Fatalf("failed to build TLS config: %v", err)
    }

    upstream, err := url.Parse(getEnvOrDefault("UPSTREAM_URL", "http://localhost:8080"))
    if err != nil {
        log.Fatalf("failed to parse upstream URL: %v", err)
    }

    addr := ":" + getEnvOrDefault("LISTEN_PORT", "8443")
    srv := &http.Server{
        Addr:      addr,
        Handler:   middleware.Logging(httputil.NewSingleHostReverseProxy(upstream)),
        TLSConfig: tlsCfg,
    }

    // create TCP listener separately from ServeTLS
    ln, err := net.Listen("tcp", addr)
    if err != nil {
        log.Fatalf("failed to listen on %s: %v", addr, err)
    }

    log.Printf("proxy listening on %s → %s", addr, upstream)

    // use goroutine to run the server in the background
    // serve the existing tlsconfig
    // ignore normal shutdown error
    go func() {
        if err := srv.ServeTLS(ln, "", ""); err != nil && err != http.ErrServerClosed {
            log.Fatalf("server error: %v", err)
        }
    }()

    // create connection
    sigCh := make(chan os.Signal, 1)
    // notify on container stop otherwise keep alive
    signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
    <-sigCh
    log.Println("shutting down...")
}

// helpers

func ensureCertDir(path string) error {
    dir := filepath.Dir(path)
    return os.MkdirAll(dir, 0700)
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
