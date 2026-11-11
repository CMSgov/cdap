package endpoints

import (
	"net/http"
	"testing"

	"github.com/navapbc/its-log/internal/consolidate"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/testsupport"
	"github.com/navapbc/its-log/internal/types"
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
			"date":      types.NewYYYYMMDD().String(),
			"kind":      "daily",
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
			"date":      types.NewYYYYMMDD().String(),
			"kind":      "daily",
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
			"date":      types.NewYYYYMMDD().String(),
			"kind":      "daily",
			"tags":      []string{"x", "y", "z"},
			"operation": "empty.object",
			"data":      map[string]any{}},
	},
}

func TestSummaryCreate(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)
	engine := testsupport.SetupTestRouter(t, SetupRouter)
	app := types.App{
		AppId: "pupper",
		KeyId: "pupper_create_key_123",
	}

	// Create some test DBs
	testsupport.CreateInstanceDbs(t, app, 2, 50)
	// Consolidate them
	err := consolidate.Consolidate(&metabase.DailyParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	})
	if err != nil {
		t.Error(err)
	}

	// Now we can test inserting summaries; we have to have daily databases
	// if we're going to insert daily summaries
	for _, tt := range scts {
		_, w := testsupport.TestPost(t, engine, tt.key, tt.path, tt.data, tt.status)
		if w.Code > 202 {
			t.Error("post failed")
		}
	}
}
