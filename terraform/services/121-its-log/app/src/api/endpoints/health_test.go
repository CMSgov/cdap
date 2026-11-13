package endpoints

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/testsupport"
	testify "github.com/stretchr/testify/assert"
)

// health
func TestHealth(t *testing.T) {
	engine := testsupport.SetupTestRouter(t, SetupRouter)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/v1/health", nil)
	engine.ServeHTTP(w, req)
	testify.Equal(t, 200, w.Code)
}
