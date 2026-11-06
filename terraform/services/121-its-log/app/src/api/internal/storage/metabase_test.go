package storage

import (
	"os"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/spf13/viper"
)

func setupMetabaseEnv(t *testing.T) {
	// Env vars
	os.Setenv("ITSLOG_STORAGE_PATH", t.TempDir())
	os.Setenv("ITSLOG_ARCHIVE_PATH", t.TempDir())
	os.Setenv("ITSLOG_EXPORT_PATH", t.TempDir())

	// Load 'em up
	replacer := strings.NewReplacer(".", "_")
	viper.SetEnvKeyReplacer(replacer)
	viper.SetEnvPrefix("ITSLOG")
	viper.AutomaticEnv()
}

func TestOpen(t *testing.T) {
	setupMetabaseEnv(t)
	tests := []struct {
		location FilesystemLocation
		filename string
		mode     MetabaseOpenMode
		pass     bool
		expected string
	}{
		// If we try and open existing only, it won't work.
		{
			location: Live,
			filename: "pupper_daily",
			mode:     OpenExistingOnly,
			pass:     false,
			expected: "does not",
		},
		// If we allow creation, it will work
		{
			location: Live,
			filename: "pupper_daily",
			mode:     OpenExistingOrCreateNew,
			pass:     true,
			expected: "IGNORED",
		},
		// This should also work, the db exists
		{
			location: Live,
			filename: "pupper_daily",
			mode:     ReplaceExisting,
			pass:     true,
			expected: "IGNORED",
		},
		// This should fail, the db does not exist
		{
			location: Live,
			filename: "pupper_nope",
			mode:     ReplaceExisting,
			pass:     false,
			expected: "does not exist",
		},
	}

	for ndx, tt := range tests {
		t.Logf("TestOpen: %d", ndx)

		m, err := NewMetabase(tt.location, tt.filename)
		if err != nil {
			t.Error(err)
		}
		if m.filename != tt.filename+"."+DUCKDB_EXTENSION {
			t.Error("filenames do not match")
		}

		var before os.FileInfo
		var after os.FileInfo
		if tt.mode == ReplaceExisting {
			// t.Log(os.ReadDir(m.path))
			before, err = os.Stat(m.FullFilename())
			if err != nil {
				// if is possible the file does not exist in the first instance.
			}

		}
		// "/var/folders/hf/hbf81j7j2d765_zrwnh6s_dh0000gp/T/TestOpen2481285748/001"
		// "/var/folders/hf/hbf81j7j2d765_zrwnh6s_dh0000gp/T/TestOpen2481285748/001"
		time.Sleep(5 * time.Millisecond)
		openErr := m.Open(tt.mode)

		if openErr != nil && tt.pass == false {
			matched, err := regexp.MatchString(tt.expected, openErr.Error())
			if err != nil {
				t.Error("regex error: " + err.Error())
			}
			if !matched {
				t.Errorf("failed to match error: %v", m)
			}
			continue
		} else if openErr != nil {
			// everything was fine!
		}

		if tt.mode == ReplaceExisting {
			// t.Log(os.ReadDir(m.path))
			after, err = os.Stat(m.FullFilename())
			if err != nil {
				t.Error("after: " + err.Error())
			}
		}

		// If we are creating new OR replacing if exists, then
		// the stat should not be the same on these.
		if tt.mode == ReplaceExisting {
			// If it was create new, then we should nave a nil and valid value.
			if before == nil && after != nil {
				// good!
			}
			// If both existed, the time should have changed
			if before != nil && after != nil {
				if before.ModTime().Equal(after.ModTime()) {
					t.Error("replace if exists has same timestamps")
				}
			}
		}

	}
}
