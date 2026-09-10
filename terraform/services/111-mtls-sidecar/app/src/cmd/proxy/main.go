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

	if err := acquireCertificates(ctx, paths); err != nil {
		log.Fatalf("failed to acquire certificates: %v", err)
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

	healthSrv := startHealthServer(getEnvOrDefault("HEALTH_PORT", "8081"))
	proxyAddr := ":" + getEnvOrDefault("PROXY_LISTEN_PORT", "8443")
	proxySrv, err := startProxyServer(proxyAddr, upstream, tlsCfg)
	if err != nil {
		log.Fatalf("failed to start proxy server: %v", err)
	}

	runStartupSelfTest(proxyAddr, paths)

	waitForShutdown(healthSrv, proxySrv)
}

// acquireCertificates fetches certs from ACM unless local certs are in use.
func acquireCertificates(ctx context.Context, paths acm.CertPaths) error {
	if getEnvOrDefault("USE_LOCAL_CERTS", "false") == "true" {
		log.Println("USE_LOCAL_CERTS=true — skipping ACM fetch")
		return nil
	}

	certARN := requireEnv("ACM_CERTIFICATE_ARN")
	client, err := acm.New(ctx, certARN, paths)
	if err != nil {
		return fmt.Errorf("creating ACM client: %w", err)
	}
	if err := client.FetchAndStore(ctx); err != nil {
		return fmt.Errorf("fetching certificate: %w", err)
	}
	log.Println("certificate fetched from ACM")
	return nil
}

// startHealthServer starts the plain-HTTP health endpoint used by
// ECS/ALB health checks. Never requires a client cert.
func startHealthServer(port string) *http.Server {
	addr := ":" + port
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	srv := &http.Server{Addr: addr, Handler: mux}

	go func() {
		log.Printf("health check listening on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("health server error: %v", err)
		}
	}()
	return srv
}

// startProxyServer starts the strict-mTLS reverse proxy.
func startProxyServer(addr string, upstream *url.URL, tlsCfg *tls.Config) (*http.Server, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.Handle("/", middleware.Logging(httputil.NewSingleHostReverseProxy(upstream)))

	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, fmt.Errorf("listening on %s: %w", addr, err)
	}

	srv := &http.Server{Addr: addr, Handler: mux, TLSConfig: tlsCfg}

	go func() {
		log.Printf("proxy listening on %s → %s (strict mTLS)", addr, upstream)
		if err := srv.ServeTLS(ln, "", ""); err != nil && err != http.ErrServerClosed {
			log.Fatalf("proxy server error: %v", err)
		}
	}()
	return srv, nil
}

// runStartupSelfTest verifies the full mTLS handshake before accepting
// real traffic. Exits the process on failure — see selftest package docs.
func runStartupSelfTest(proxyAddr string, paths acm.CertPaths) {
	log.Println("running mTLS startup self-test...")
	if err := selftest.WaitAndVerifyMTLS(
		"localhost"+proxyAddr,
		paths.CAFile,
		getEnvOrDefault("SELFTEST_CERT_FILE", paths.CertFile),
		getEnvOrDefault("SELFTEST_KEY_FILE", paths.KeyFile),
		getEnvOrDefault("SELFTEST_SERVER_NAME", ""),
		5,
		500*time.Millisecond,
	); err != nil {
		log.Fatalf("mTLS startup self-test failed — refusing to start: %v", err)
	}
	log.Println("mTLS startup self-test passed ✅")
}

// waitForShutdown blocks until SIGTERM/SIGINT, then gracefully shuts
// down both servers.
func waitForShutdown(healthSrv, proxySrv *http.Server) {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	<-sigCh
	log.Println("shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

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
