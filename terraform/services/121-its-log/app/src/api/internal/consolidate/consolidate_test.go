package consolidate

import (
	"fmt"
	"os"
	"path"
	"regexp"
	"testing"
	"time"
	"uuid"

	"github.com/navapbc/its-log/internal/csp"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/testsupport"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"github.com/stretchr/testify/assert"
)

// This creates files that we may want to inspect
var cleanupTests bool = true
var eventsPerInstance int = 100
var instanceCount int = 4

// Setting this to `true` will use ${HOME}/.its-log/... for the
// creation of instance databases and the archived data. Good for debugging
// and local testing. Leaving it `false` will use a t.TempDir() which is
// cleaned up automatically by the test engine.
var useHomeDirectory bool = false

func TestConsolidate(t *testing.T) {
	app := types.RandomApp("puppers")
	createInstanceDbs(t, app)
	// This consolidates the DBs, and makes sure they exist
	createConsolidatedDbs(app, t)
	// Now, is the data in the databases?
	checkInstanceDataInConsolidatedDbs(app, t)
	if cleanupTests {
		cleanupDirectories(t, app)
	}
}

func checkInstanceDataInConsolidatedDbs(app types.App, t *testing.T) {
	dd, err := metabase.NewDailyDatabase(app, types.NewYYYYMMDD().String())
	if err != nil {
		t.Error(err)
	}
	checkIM(t, dd)

	md, err := metabase.NewMonthlyDatabase(app, time.Now().Year(), int(time.Now().Month()))
	if err != nil {
		t.Error(err)
	}
	checkIM(t, md)

	yd, err := metabase.NewYearlyDatabase(app, time.Now().Year())
	if err != nil {
		t.Error(err)
	}
	checkIM(t, yd)

	fd, err := metabase.NewFullDatabase(app)
	if err != nil {
		t.Error(err)
	}
	checkIM(t, fd)

}

func checkIM(t *testing.T, im metabase.IMetabase) {
	err := im.Open(metabase.OpenExistingOnly)
	if err != nil {
		t.Error(err)
	}
	defer im.Close()
	db := im.GetDB()

	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM event").Scan(&count)
	if err != nil {
		t.Error(err)
	}
	assert.Equal(t, instanceCount*eventsPerInstance, count)
}

func createConsolidatedDbs(app types.App, t *testing.T) {
	dp := DailyParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	}
	assertConsolidated(t, &dp)

	mp := MonthlyParams{
		App:         app,
		YearNumber:  time.Now().Year(),
		MonthNumber: int(time.Now().Month()),
	}
	assertConsolidated(t, &mp)

	yp := YearlyParams{
		App:        app,
		YearNumber: time.Now().Year(),
	}
	assertConsolidated(t, &yp)

	fp := FullParams{
		App: app,
	}
	assertConsolidated(t, &fp)
}

func assertConsolidated(t *testing.T, cp ConsolidationParams) {
	Consolidate(cp)
	count := countFiles(cp.Glob())
	assert.Greater(t, count, 0)
}

func createInstanceDbs(t *testing.T, app types.App) {
	testsupport.SetupTestEnv(t)
	if useHomeDirectory {
		os.Setenv("ITSLOG_STORAGE_PATH", path.Join(os.Getenv("HOME"), ".its-log", "data"))
		os.Setenv("ITSLOG_ARCHIVE_PATH", path.Join(os.Getenv("HOME"), ".its-log", "archive"))
	}

	for range instanceCount {
		os.Setenv("ITSLOG_INSTANCE_ID", fmt.Sprintf("CT-%s", uuid.New().String()))
		e1 := testsupport.CreateEvents(app, eventsPerInstance)
		inserted, err := csp.ManyEvents(e1)
		if err != nil {
			t.Error(err)
		}
		assert.Equal(t, int64(eventsPerInstance), inserted)
	}
}

func cleanupDirectories(t *testing.T, app types.App) {
	for _, dir := range []string{"data", "archive"} {
		var baseDir string
		if useHomeDirectory {
			baseDir = path.Join(os.Getenv("HOME"), ".its-log", dir)
		} else {
			if dir == "data" {
				baseDir = viper.GetString("storage.path")
			} else {
				baseDir = viper.GetString("archive.path")
			}
		}

		entries, err := os.ReadDir(baseDir)
		if err != nil {
			t.Error("could not read dir for cleanup")
		}
		for _, e := range entries {
			m, _ := regexp.MatchString(app.AppId, e.Name())
			if m {
				os.Remove(path.Join(baseDir, e.Name()))
			}
		}
	}
}
