package endpoints

import (
	"net/http"
	"net/http/httptest"
	"testing"

	testify "github.com/stretchr/testify/assert"
)

// health
func TestHealth(t *testing.T) {
	engine := setupEnv(t)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/v1/health", nil)
	engine.ServeHTTP(w, req)
	testify.Equal(t, 200, w.Code)
}
