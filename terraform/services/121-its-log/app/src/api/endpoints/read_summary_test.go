package endpoints

import (
	"encoding/json"
	"net/http"
	"reflect"
	"slices"
	"testing"

	"github.com/navapbc/its-log/internal/testsupport"
	"github.com/stretchr/testify/assert"
)

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
	engine := testsupport.SetupTestRouter(t, SetupRouter)

	// We need to create things first.
	for _, tt := range scts {
		testsupport.TestPost(t, engine, tt.key, tt.path, tt.data, tt.status)
	}

	for _, tt := range srts {
		res, err := testsupport.TestPost(t, engine, tt.key, tt.path, tt.data, tt.status)
		if err != nil {
			t.Error(err)
		}
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
