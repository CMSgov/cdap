package storage

import (
	"os"
	"path"
	"slices"
	"strings"
	"testing"

	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
)

// These are mostly "happy-path" tests.
// It does not test bad paths for data storage,
// nor does it test pathological application names.
// As an internal library of code, it is assuming that the production
// deployment happens with reasonable values for these things.

var sdbt = []struct {
	appId string
	date  string
}{
	{"app", "2026-01-02"},
	{"app", "today"},
	{"app", "yesterday"},
}

func setupEnv() {
	// Env vars
	os.Setenv("ITSLOG_STORAGE_PATH", "/tmp")

	// Load 'em up
	replacer := strings.NewReplacer(".", "_")
	viper.SetEnvKeyReplacer(replacer)
	viper.SetEnvPrefix("ITSLOG")
	viper.AutomaticEnv()
}

// *  *  *  *
// DoesDbExist
func TestDoesDBExist(t *testing.T) {
	setupEnv()
	for _, tt := range sdbt {
		s, err := SetupDB(tt.appId, tt.date, LiveStorage)
		if err != nil {
			t.Errorf("SetupDB failed with %s, %s", tt.appId, tt.date)
		}
		info, err := os.Stat(path.Join(s.Path...))
		yn := DoesDBExist(s.Path)
		if (info.Size() > 0) && !yn {
			t.Error("conflicting reports on DB existence")
		}
	}
}

// *  *  *  *
// SetupDB
func TestSetupDb(t *testing.T) {
	setupEnv()
	for _, tt := range sdbt {
		s, err := SetupDB(tt.appId, tt.date, LiveStorage)
		if err != nil {
			t.Errorf("SetupDB failed with %s, %s", tt.appId, tt.date)
		}
		if s.AppId != tt.appId {
			t.Error("app id does not match")
		}
		correct, err := types.SanitizeDate(tt.date)
		if err != nil {
			t.Errorf("could not sanitize date %s", tt.date)
		}

		if s.ILTime.AsYYYYMMDD() != correct {
			t.Errorf("dates do not match: %s %s", s.ILTime.AsYYYYMMDD(), correct)
		}
		info, err := os.Stat(path.Join(s.Path...))
		if !(info.Size() > 0) {
			t.Error("db file does not exist, or is not size > 0")
		}
	}
}

// *  *  *  *
// NewStorage
func TestNewStorage(t *testing.T) {
	s, err := NewStorage("app")
	if err != nil {
		t.Error("could not create storage")
	}
	if s.AppId != "app" {
		t.Error("app id incorrectly assigned")
	}
	if s.ILTime.AsYYYYMMDD() != types.NewILTimeToday().AsYYYYMMDD() {
		t.Error("date is not today")
	}
}

// *  *  *  *
//  ConstructDBFilenameAndPath
func TestConstructDBFilenameAndPath(t *testing.T) {
	setupEnv()
	filename, path := ConstructDBFilenameAndPath("a", "b")
	if filename != "a_b.duckdb" {
		t.Error("filename constructed incorrectly")
	}
	if slices.Compare(path, []string{viper.GetString("storage.path"), "a_b.duckdb"}) != 0 {
		t.Errorf("path constructed incorrectly: %s", path)
	}
}

// *  *  *  *
// GenerateNamedArgs
var nat = []struct {
	sql     string
	params  EmbedParamMap
	correct bool
	len     int
}{
	{"SELECT * FROM table", EmbedParamMap{}, true, 0},
	{"SELECT * FROM table", EmbedParamMap{"arg": "v"}, false, 0},
	{"SELECT * FROM table where x = $y", EmbedParamMap{"y": "v"}, true, 1},
	{"SELECT * FROM table where x = $y", EmbedParamMap{"y": []string{"hi"}}, true, 1},
	{"SELECT * FROM table where x = $y", EmbedParamMap{"y": []any{"hi"}}, true, 1},
	{"SELECT * FROM table where x = $y", EmbedParamMap{"x": "v"}, false, 1},
	{"SELECT * FROM table where x = $y", EmbedParamMap{}, false, 1},
	{"SELECT * FROM table where x = $y AND z = $a",
		EmbedParamMap{"y": "v", "a": "v"}, true, 2},
	{"SELECT * FROM table where x = $y AND z = $a",
		EmbedParamMap{"y": "v", "a": types.M{"1": "2"}}, true, 2},
}

func TestGenerateNamedArgs(t *testing.T) {
	for _, tt := range nat {
		arr, err := GenerateNamedArgs(tt.sql, tt.params)
		t.Logf("%v %s", arr, err)
		if err != nil && !tt.correct {
			return
		}
		if len(arr) != tt.len {
			t.Errorf("found wrong number of args: %d %v", tt.len, arr)
		}
	}
}

func TestGenerateNamedArgsNotJson(t *testing.T) {
	var badValue map[*EmbedParamMap]*float32 = make(map[*EmbedParamMap]*float32)

	var x float32 = 8.0
	badValue[&EmbedParamMap{}] = &x
	_, err := GenerateNamedArgs(
		"SELECT * FROM table where x = $y AND z = $a",
		EmbedParamMap{"y": badValue},
	)
	if err == nil {
		t.Error("there is no way that should work")
	}
}
