package metabase

import (
	"fmt"
	"math/rand/v2"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"github.com/stretchr/testify/assert"
)

func setupMetabaseEnv(t *testing.T) {
	// Env vars
	os.Setenv("ITSLOG_STORAGE_PATH", t.TempDir())
	os.Setenv("ITSLOG_ARCHIVE_PATH", t.TempDir())
	os.Setenv("ITSLOG_EXPORT_PATH", t.TempDir())
	os.Setenv("ITSLOG_INSTANCE_ID", fmt.Sprintf("THE-INSTANCE-ID-%d", rand.IntN(1000)))
	// Load 'em up
	replacer := strings.NewReplacer(".", "_")
	viper.SetEnvKeyReplacer(replacer)
	viper.SetEnvPrefix("ITSLOG")
	viper.AutomaticEnv()
}

func TestInstanceDatabaseExistence(t *testing.T) {
	setupMetabaseEnv(t)
	id, err := NewInstanceDatabase(types.App{AppId: "app0123", KeyId: "key0123"})
	if err != nil {
		t.Error(err)
	}
	// t.Log(id.FullFilename())
	assert.False(t, CheckExists(id))
	id.Open(OpenExistingOrCreateNew)
	assert.True(t, CheckExists(id))
}

func _touch(filename string) error {
	file, err := os.OpenFile(filename, os.O_RDONLY|os.O_CREATE, 0644)
	if err != nil {
		return err
	}
	file.Close() // Close immediately to avoid resource leaks
	now := time.Now()
	err = os.Chtimes(filename, now, now)
	if err != nil {
		return err
	}

	return nil
}
func TestCreateNew(t *testing.T) {
	setupMetabaseEnv(t)
	id, err := NewInstanceDatabase(types.App{AppId: "app0123", KeyId: "key0123"})
	if err != nil {
		t.Error(err)
	}
	// Cannot create a new file if it exists
	_touch(id.FullFilename())
	assert.True(t, CheckExists(id))
	err = id.Open(CreateNew)
	assert.Error(t, err)
	id.Close()

	// Can create a new file if it does not exist
	os.Remove(id.FullFilename())
	assert.False(t, CheckExists(id))
	err = id.Open(CreateNew)
	assert.NoError(t, err)
	assert.True(t, CheckExists(id))
	id.Close()
}

func TestOpenExisting(t *testing.T) {
	setupMetabaseEnv(t)
	id, err := NewInstanceDatabase(types.App{AppId: "app0123", KeyId: "key0123"})
	if err != nil {
		t.Error(err)
	}
	// Can open existing
	os.Remove(id.FullFilename())
	assert.False(t, CheckExists(id))
	err = id.Open(CreateNew)
	assert.NoError(t, err)
	assert.True(t, CheckExists(id))
	err = id.Close()
	assert.NoError(t, err)
	err = id.Open(OpenExistingOnly)
	assert.NoError(t, err)

	// Can not open a file that does not exist
	os.Remove(id.FullFilename())
	assert.False(t, CheckExists(id))
	err = id.Open(OpenExistingOnly)
	assert.False(t, CheckExists(id))
	assert.Error(t, err)
	id.Close()
}

func TestReplaceExisting(t *testing.T) {
	setupMetabaseEnv(t)
	id, e0 := NewInstanceDatabase(types.App{AppId: "app0123", KeyId: "key0123"})
	if e0 != nil {
		t.Error(e0)
	}
	// Can only replace a file that exists
	os.Remove(id.FullFilename())
	e1 := id.Open(ReplaceExisting)
	assert.Error(t, e1)

	// Can replace a file that exists
	os.Remove(id.FullFilename())
	e2 := id.Open(CreateNew)
	assert.NoError(t, e2)
	id.Close()
	assert.True(t, CheckExists(id))
	before, _ := os.Stat(id.FullFilename())
	time.Sleep(5 * time.Millisecond)

	e3 := id.Open(ReplaceExisting)
	assert.NoError(t, e3)
	id.Close()
	after, _ := os.Stat(id.FullFilename())
	// Assert that the files have diff timestamps
	assert.True(t, before.ModTime().Before(after.ModTime()))
}
