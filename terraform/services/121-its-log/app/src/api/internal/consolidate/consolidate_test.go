package consolidate

import (
	"os"
	"path"
	"regexp"
	"testing"
	"time"

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
var useHomeDirectory bool = true

func TestConsolidate(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.GlobalTestStorageLocation)
	app := types.RandomApp("puppers")
	testsupport.CreateInstanceDbs(t, app, instanceCount, eventsPerInstance)
	// This consolidates the DBs, and makes sure they exist
	createConsolidatedDbs(app, t)
	// Now, is the data in the databases?
	checkInstanceDataInConsolidatedDbs(app, t)
	if cleanupTests {
		cleanupDirectories(t, app)
	}
}

func checkInstanceDataInConsolidatedDbs(app types.App, t *testing.T) {
	dd, err := metabase.NewDailyDatabase(&metabase.DailyParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	})
	if err != nil {
		t.Error(err)
	}
	checkIM(t, dd)

	md, err := metabase.NewMonthlyDatabase(&metabase.MonthlyParams{
		App:         app,
		YearNumber:  time.Now().Year(),
		MonthNumber: int(time.Now().Month()),
	})

	if err != nil {
		t.Error(err)
	}
	checkIM(t, md)

	yd, err := metabase.NewYearlyDatabase(&metabase.YearlyParams{
		App:        app,
		YearNumber: time.Now().Year(),
	})

	if err != nil {
		t.Error(err)
	}
	checkIM(t, yd)

	fd, err := metabase.NewFullDatabase(&metabase.FullParams{App: app})
	if err != nil {
		t.Error(err)
	}
	checkIM(t, fd)

}

func checkIM(t *testing.T, m *metabase.Metabase) {
	err := m.Open(metabase.OpenExistingOnly)
	if err != nil {
		t.Error(err)
	}
	defer m.Close()
	db := m.GetDB()

	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM event").Scan(&count)
	if err != nil {
		t.Error(err)
	}
	assert.Equal(t, instanceCount*eventsPerInstance, count)
}

func createConsolidatedDbs(app types.App, t *testing.T) {
	dp := metabase.DailyParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	}
	assertConsolidated(t, &dp)

	mp := metabase.MonthlyParams{
		App:         app,
		YearNumber:  time.Now().Year(),
		MonthNumber: int(time.Now().Month()),
	}
	assertConsolidated(t, &mp)

	yp := metabase.YearlyParams{
		App:        app,
		YearNumber: time.Now().Year(),
	}
	assertConsolidated(t, &yp)

	fp := metabase.FullParams{
		App: app,
	}
	assertConsolidated(t, &fp)
}

func assertConsolidated(t *testing.T, cp metabase.MetaParams) {
	Consolidate(cp)
	count := countFiles(cp.Glob())
	assert.Greater(t, count, 0)
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
