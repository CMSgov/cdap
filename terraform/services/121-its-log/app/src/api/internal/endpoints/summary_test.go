package endpoints

import (
	"net/http"
	"testing"
)

// summary
func TestSummaryCreate(t *testing.T) {
	data := map[string]any{
		"date":      "today",
		"tags":      []string{"%"},
		"operation": "test",
		"data": map[string]any{
			"count": 42,
		},
	}
	testPost(t, "/v1/summary/create", data, http.StatusCreated)
}

func TestSummaryCreateNoBind(t *testing.T) {
	data := map[string]any{
		"date":      "today",
		"tags":      []string{"%"},
		"operation": "test",
		"data":      42, // Must be a map
	}
	testPost(t, "/v1/summary/create", data, http.StatusBadRequest)
}

func TestSummaryRead(t *testing.T) {
	data := map[string]any{
		"date":      "today",
		"tags":      "%",
		"operation": "test",
	}
	testPost(t, "/v1/summary/read", data, http.StatusOK)
}
