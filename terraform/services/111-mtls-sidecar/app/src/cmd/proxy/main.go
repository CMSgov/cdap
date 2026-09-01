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
	"syscall"
	"time"

	"mtls-sidecar/internal/acm"
	"mtls-sidecar/internal/middleware"
	"mtls-sidecar/internal/selftest"
	tlsconfig "mtls-sidecar/internal/tls"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	paths := acm.CertPaths{
		CertFile: getEnvOrDefault("TLS_CERT_FILE", "/run/certs/cert.pem"),
		KeyFile:  getEnvOrDefault("TLS_KEY_FILE", "/run/certs/key.pem"),
		CAFile:   getEnvOrDefault("TLS_CA_FILE", "/run/certs/ca.pem"),
	}

	if getEnvOrDefault("USE_LOCAL_CERTS", "false") != "true" {
		certARN := requireEnv("ACM_CERTIFICATE_ARN")
		client, err := acm.New(ctx, certARN, paths)
		if err != nil {
			log.Fatalf("failed to create ACM client: %v", err)
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

	// -------------------------------------------------------
	// Health check server — plain HTTP, dedicated port
	// Only serves /health — no TLS, no client cert required
	// Used by ECS container health check and ALB health check
	// -------------------------------------------------------
	healthAddr := ":" + getEnvOrDefault("HEALTH_PORT", "8081")
	healthMux := http.NewServeMux()
	healthMux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	healthSrv := &http.Server{
		Addr:    healthAddr,
		Handler: healthMux,
	}
	go func() {
		log.Printf("health check listening on %s", healthAddr)
		if err := healthSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("health server error: %v", err)
		}
	}()

	// -------------------------------------------------------
	// mTLS proxy server — strict mTLS, no exceptions
	// All traffic on this port requires a valid client cert
	// /health included here only for the startup self-test
	// -------------------------------------------------------
	proxyAddr := ":" + getEnvOrDefault("PROXY_LISTEN_PORT", "8443")
	proxyMux := http.NewServeMux()

	// /health on the mTLS port — used only by the startup self-test
	// requires a valid client cert like all other routes on this port
	proxyMux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// All other traffic — proxied upstream
	proxyMux.Handle("/", middleware.Logging(
		httputil.NewSingleHostReverseProxy(upstream),
	))

	ln, err := net.Listen("tcp", proxyAddr)
	if err != nil {
		log.Fatalf("failed to listen on %s: %v", proxyAddr, err)
	}

	proxySrv := &http.Server{
		Addr:      proxyAddr,
		Handler:   proxyMux,
		TLSConfig: tlsCfg,
	}

	log.Printf("proxy listening on %s → %s (strict mTLS)", proxyAddr, upstream)

	go func() {
		if err := proxySrv.ServeTLS(ln, "", ""); err != nil && err != http.ErrServerClosed {
			log.Fatalf("proxy server error: %v", err)
		}
	}()

	// -------------------------------------------------------
	// mTLS startup self-test
	// Verifies the full mTLS handshake works before accepting
	// real traffic. If this fails the container exits with a
	// non-zero code — ECS marks it unhealthy and the deployment
	// circuit breaker triggers a rollback to the last good task.
	// -------------------------------------------------------
	log.Println("running mTLS startup self-test...")
    if err := selftest.WaitAndVerifyMTLS(
        "localhost"+proxyAddr,
        paths.CAFile,
        getEnvOrDefault("SELFTEST_CERT_FILE", paths.CertFile),
        getEnvOrDefault("SELFTEST_KEY_FILE",  paths.KeyFile),
        getEnvOrDefault("SELFTEST_SERVER_NAME", ""),
        5,
        500*time.Millisecond,
    ); err != nil {
        log.Fatalf("mTLS startup self-test failed — refusing to start: %v", err)
    }
	log.Println("mTLS startup self-test passed ✅")

	// -------------------------------------------------------
	// Wait for shutdown signal
	// -------------------------------------------------------
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	<-sigCh
	log.Println("shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := healthSrv.Shutdown(shutdownCtx); err != nil {
		log.Printf("health server shutdown error: %v", err)
	}
	if err := proxySrv.Shutdown(shutdownCtx); err != nil {
		log.Printf("proxy server shutdown error: %v", err)
	}
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
