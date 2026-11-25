package endpoints

import (
	"encoding/json"
	"net/http"
	"reflect"
	"slices"
	"testing"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/consolidate"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/testsupport"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/types"
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
		types.M{
			"consolidation_timeframe": "daily",
			"operation":               "just.%",
			"tags":                    []string{"a"},
			"ymd":                     types.NewYYYYMMDD().String(),
		},
		float64(42),
	},
	// Returns a 200.
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		types.M{
			"consolidation_timeframe": "daily",
			"operation":               "map.42",
			"tags":                    []string{"a"},
			"ymd":                     types.NewYYYYMMDD().String(),
		},
		types.M{
			"count": float64(42),
		},
	},
	{
		"admin",
		"/v1/summary/read",
		// When we expect no content, the comparison to the
		// expected value will not happen. We check to see that
		// it is specified as `nil`.
		http.StatusBadRequest,
		types.M{
			"consolidation_timeframe": "daily",
			"operation":               "map.42",
			"tags":                    "bad-tags",
			"ymd":                     types.NewYYYYMMDD().String(),
		},
		nil,
	},
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		types.M{
			"consolidation_timeframe": "daily",
			"operation":               "map.42",
			"tags":                    []string{"a"},
			"ymd":                     types.NewYYYYMMDD().String(),
		},
		map[string]any{
			"count": float64(42),
		},
	},
	{
		"admin",
		"/v1/summary/read",
		http.StatusOK,
		types.M{
			"consolidation_timeframe": "daily",
			"language":                "sql",
			"operation":               "empty.object",
			"tags":                    []string{"x", "y", "z"},
			"ymd":                     types.NewYYYYMMDD().String(),
		},
		types.M{},
	},
}

func TestSummaryRead(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)
	engine := testsupport.SetupTestRouter(t, SetupRouter)

	// Create some test DBs
	app := types.App{
		AppId: "pupper",
		KeyId: "pupper_create_key_123",
	}
	// Cleanup from other tests
	err := testsupport.CleanupTestDirectory("storage.path", app.AppId)
	if err != nil {
		t.Error(err)
	}
	testsupport.CleanupTestDirectory("archive.path", app.AppId)
	if err != nil {
		t.Error(err)
	}

	testsupport.CreateInstanceDbs(t, app, 2, 50)
	// Consolidate them
	err = consolidate.Consolidate(&metabase.DailyParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	})
	if err != nil {
		t.Error(err)
	}

	// First, run the table from the create_summary_test.
	// This inserts summaries that can be read back.
	for _, tt := range scts {
		_, w := testsupport.TestPost(t, engine, tt.key, tt.path, tt.data, tt.status)
		if w.Code > 299 {
			t.Error("post failed")
		}
	}

	for _, tt := range srts {
		res, w := testsupport.TestPost(t, engine, tt.key, tt.path, tt.data, tt.status)
		if w.Code > 299 {
			if tt.status == w.Code && tt.expected == nil {
				// pass
				continue
			} else {
				t.Error(w.Body)
			}
		}
		if slices.Contains([]int{http.StatusOK}, tt.status) {
			var ret map[string]any
			err := json.Unmarshal(res, &ret)
			if err != nil {
				t.Errorf("could not unmarshal response: %s", res)
			}

			b := reflect.DeepEqual(ret["data"], tt.expected)
			if !b {
				t.Log(ret["data"])
				t.Log(tt.expected)
			}
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
