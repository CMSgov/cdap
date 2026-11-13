package metabase

import (
	"database/sql"
	"testing"
	"time"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/embedfs"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	_ "github.com/duckdb/duckdb-go/v2"
)

var tgnat = []struct {
	statement string
	params    []embedfs.EmbeddedParam
	pass      bool
}{
	{"insert into test (data) values ($v)",
		[]embedfs.EmbeddedParam{{
			Name:  "v",
			Value: "string-x",
			Type:  embedfs.EmbeddedJson,
		}},
		true},
	{"insert into test (data) values ($v)",
		[]embedfs.EmbeddedParam{{
			Name:  "v",
			Value: 3,
			Type:  embedfs.EmbeddedJson,
		}},
		true},
	{"insert into test (data) values ($v)",
		[]embedfs.EmbeddedParam{{
			Name: "v",
			Value: types.M{
				"hello": "goodbye",
			},
			Type: embedfs.EmbeddedJson,
		}},
		true},
	{"insert into test (inserted) values ($v)",
		[]embedfs.EmbeddedParam{{
			Name:  "v",
			Value: time.Now(),
			Type:  embedfs.EmbeddedTime,
		}},
		true},
}

func TestGenerateNamedArgs(t *testing.T) {
	db, err := sql.Open("duckdb", ":memory:")
	if err != nil {
		t.Error(err)
	}
	_, err = db.Exec(`
	create table test (
	  data json,
	  inserted DATETIME
	)
	`)
	if err != nil {
		t.Error(err)
	}
	for _, tt := range tgnat {
		named_args, err := PrepareNamedArgs(tt.statement, tt.params)
		if err != nil {
			t.Errorf("could not generate named args: %v", tt.params)
		}
		_, err = db.Exec(tt.statement, named_args...)
		if err != nil {
			if tt.pass {
				t.Error(err)
			} else {
				t.Log("passed: " + err.Error())
			}
		}

	}
}
