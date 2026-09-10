package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("HEALTH_PORT")
	if port == "" {
		port = "8081"
	}

	resp, err := http.Get(fmt.Sprintf("http://localhost:%s/health", port))
	if err != nil {
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		os.Exit(1)
	}

	os.Exit(0)
}
