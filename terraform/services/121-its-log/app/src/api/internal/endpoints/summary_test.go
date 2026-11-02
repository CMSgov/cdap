package endpoints

import (
	"net/http"
	"testing"
)

func TestSummary(t *testing.T) {
	var tests = []struct {
		key    string
		path   string
		status int
		data   map[string]any
	}{
		// Good call, creates DB
		{
			"admin",
			"/v1/summary/create",
			http.StatusCreated,
			map[string]any{
				"date":      "today",
				"tags":      []string{"%"},
				"operation": "test",
				"data": map[string]any{
					"count": 42,
				}},
		},
		// Bad call, malformed binding
		{
			"admin",
			"/v1/summary/create",
			http.StatusBadRequest,
			map[string]any{
				"date":      "today",
				"tags":      []string{"%"},
				"operation": "test",
				"data":      42,
			},
		},
		// Good call, reads value
		{
			"admin",
			"/v1/summary/read",
			http.StatusOK,
			map[string]any{
				"date":      "today",
				"tags":      "%",
				"operation": "test",
			},
		},
	}

	for _, tt := range tests {
		testPost(t, tt.key, tt.path, tt.data, tt.status)
	}
}
