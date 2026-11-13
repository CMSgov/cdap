package endpoints

import (
	"net/http"
	"testing"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/consolidate"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/testsupport"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
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
		types.M{
			"ymd":       types.NewYYYYMMDD().String(),
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
		types.M{
			"ymd":       types.NewYYYYMMDD().String(),
			"kind":      "daily",
			"tags":      []string{"a", "b"},
			"operation": "map.42",
			"data": types.M{
				"count": 42,
			}},
	},
	// Empty object is OK
	{
		"admin",
		"/v1/summary/create",
		http.StatusCreated,
		types.M{
			"ymd":       types.NewYYYYMMDD().String(),
			"kind":      "daily",
			"tags":      []string{"x", "y", "z"},
			"operation": "empty.object",
			"data":      types.M{}},
	},
}

func TestSummaryCreate(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)

	engine := testsupport.SetupTestRouter(t, SetupRouter)
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

	// Create some test DBs
	testsupport.CreateInstanceDbs(t, app, 2, 50)
	// Consolidate them
	err = consolidate.Consolidate(&metabase.DailyParams{
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
