package main

import (
    "log"
    "net"
    "net/http"
    "net/http/httputil"
    "net/url"
    "os"

    "reverse-proxy/internal/middleware"
    tlsconfig "reverse-proxy/internal/tls"
)

func main() {
    upstream, err := url.Parse(getEnvOrDefault("UPSTREAM_URL", "http://localhost:8080"))
    if err != nil {
        log.Fatalf("failed to parse upstream URL: %v", err)
    }

    proxy := httputil.NewSingleHostReverseProxy(upstream)
    handler := middleware.Logging(proxy)

    addr := ":" + getEnvOrDefault("LISTEN_PORT", "8443")

    // Build the mTLS config
    tlsCfg, err := tlsconfig.NewServerTLSConfig(tlsconfig.Config{
        CertFile:          getEnvOrDefault("TLS_CERT_FILE", "/etc/certs/server.crt"),
        KeyFile:           getEnvOrDefault("TLS_KEY_FILE", "/etc/certs/server.key"),
        CAFile:            getEnvOrDefault("TLS_CA_FILE", "/etc/certs/ca.pem"),
        RequireClientCert: getEnvBoolOrDefault("REQUIRE_CLIENT_CERT", true),
    })
    if err != nil {
        log.Fatalf("failed to build TLS config: %v", err)
    }

    // Build the server manually so we can attach our tls.Config.
    srv := &http.Server{
        Addr:      addr,
        Handler:   handler,
        TLSConfig: tlsCfg,
    }

    // Create the TLS listener manually
    ln, err := net.Listen("tcp", addr)
    if err != nil {
        log.Fatalf("failed to create listener: %v", err)
    }

    log.Printf("proxy listening on %s (mTLS), forwarding to %s", addr, upstream)

    // ServeTLS with empty cert/key strings because
    // our tls.Config.GetCertificate handles it
    if err := srv.ServeTLS(ln, "", ""); err != nil {
        log.Fatalf("server error: %v", err)
    }
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
