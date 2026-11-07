package endpoints

import (
	"encoding/json"
	"net/http"
	"reflect"
	"slices"
	"testing"

	"github.com/stretchr/testify/assert"
)

// SummaryCreate
var scts = []struct {
	key    string
	path   string
	status int
	data   any
}{
	{
		"admin",
		"/v1/summary/create",
		http.StatusCreated,
		map[string]any{
			"date":      "yesterday",
			"tags":      []string{"a"},
			"operation": "just.42",
			"data":      42},
	},
	// Good call, creates DB
	{
		"admin",
		"/v1/summary/create",
		http.StatusCreated,
		map[string]any{
			"date":      "yesterday",
			"tags":      []string{"a", "b"},
			"operation": "map.42",
			"data": map[string]any{
				"count": 42,
			}},
	},
	// Empty object is OK
	{
		"admin",
		"/v1/summary/create",
		http.StatusCreated,
		map[string]any{
			"date":      "yesterday",
			"tags":      []string{"x", "y", "z"},
			"operation": "empty.object",
			"data":      map[string]any{}},
	},
}

func TestSummaryCreate(t *testing.T) {
	engine := setupEnv(t)
	for _, tt := range scts {
		testPost(engine, t, tt.key, tt.path, tt.data, tt.status)
	}
}

// SummaryRead
// https://pkg.go.dev/encoding/json#Unmarshal
// Note that all numbers come back from JSON unmarshaling as
// float64 values. Therefore, for testing, we need to check that
// we are getting values as floats.
var srts = []struct {
	key      string
	path     string
	status   int
	data     any
	expected any
}{
	// Good call, reads value
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		map[string]any{
			"date":      "yesterday",
			"tags":      "%",
			"operation": "just.42",
		},
		float64(42),
	},
	// Returns a 200.
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		map[string]any{
			"date":      "yesterday",
			"tags":      "%",
			"operation": "map.42",
		},
		map[string]any{
			"count": float64(42),
		},
	},
	{
		"admin",
		"/v1/summary/read",
		// When we expect no content, the comparison to the
		// expected value will not happen. We check to see that
		// it is specified as `nil`.
		http.StatusNoContent,
		map[string]any{
			"date":      "yesterday",
			"tags":      "bad-tags",
			"operation": "map.42",
		},
		nil,
	},
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		map[string]any{
			"date":      "yesterday",
			"tags":      "a%",
			"operation": "map.42",
		},
		map[string]any{
			"count": float64(42),
		},
	},
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		map[string]any{
			"date":      "yesterday",
			"tags":      "x.y.z",
			"operation": "empty.object",
		},
		map[string]any{},
	},
}

func TestSummaryRead(t *testing.T) {
	engine := setupEnv(t)

	// We need to create things first.
	for _, tt := range scts {
		testPost(engine, t, tt.key, tt.path, tt.data, tt.status)
	}

	for _, tt := range srts {
		res := testPost(engine, t, tt.key, tt.path, tt.data, tt.status)
		if slices.Contains([]int{http.StatusOK}, tt.status) {
			var ret map[string]any
			err := json.Unmarshal(res, &ret)
			if err != nil {
				t.Errorf("could not unmarshal response: %s", res)
			}

			b := reflect.DeepEqual(ret["data"], tt.expected)
			assert.True(t, b, "round trip failed")
		} else if slices.Contains([]int{http.StatusNoContent}, tt.status) {
			if tt.expected == nil {
				// StatusNoContent does not include a message body.
				// This is good. We expect the expected value to
				// come through as `nil` in this case.
			} else {
				t.Errorf("got no content, but expected a value")
			}
		} else {
			t.Errorf("should not get here")
		}
	}
}
