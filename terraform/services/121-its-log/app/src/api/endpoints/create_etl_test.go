package endpoints

import (
	"encoding/base64"
	"net/http"
	"testing"

	"github.com/navapbc/its-log/internal/consolidate"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/testsupport"
	"github.com/navapbc/its-log/internal/types"
)

var cett = []struct {
	key    string
	name   string
	sql    string
	status int
	pass   bool
}{
	{"admin", "sentinel", "select * from event", http.StatusOK, true},
	{"admin", "sentinel", "replace in place", http.StatusOK, true},
	{"admin", "space in name", "not sql but it does not matter", http.StatusOK, true},
	{"admin", "reject this", "insert into summary reject for keyword", http.StatusBadRequest, false},
	{"admin", "reject this 2", "update into summary reject for keyword", http.StatusBadRequest, false},
	{"admin", "reject this 3", "delete from summary reject for keyword", http.StatusBadRequest, false},
	{"log", "sentinel", "select * from event reject wrong key", http.StatusUnauthorized, false},
}

func TestCreateEtl(t *testing.T) {
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

	for ndx, tt := range cett {
		t.Logf("%d | %s", ndx, tt.name)
		encoded := base64.StdEncoding.EncodeToString([]byte(tt.sql))
		body := types.M{
			"ymd":  types.NewYYYYMMDD().String(),
			"kind": "daily",
			"name": "sentinel",
			"b64":  encoded,
		}

		_, w := testsupport.TestPost(t, engine, tt.key, "/v1/etl/create", body, tt.status)
		if w.Code > 202 && !tt.pass && w.Code == tt.status {
			// expected failure
		} else if w.Code > 202 {
			t.Error("unexpected failure")
		}
	}
}
