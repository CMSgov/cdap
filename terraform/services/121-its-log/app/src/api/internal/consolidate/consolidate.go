package consolidate

import (
	"errors"
	"fmt"
	"path/filepath"

	"github.com/navapbc/its-log/internal/metabase"
)

func Consolidate(cp ConsolidationParams) error {
	// Make sure we're going to match some files.
	count := countFiles(cp.Glob())
	if count < 1 {
		return errors.New("no databases match those parameters")
	}

	// Get an in-memory database to attach things to.
	inMem, err := GetInMemoryDB()
	if err != nil {
		return err
	}
	defer inMem.Close()

	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	var destination metabase.IMetabase
	switch cp := cp.(type) {
	case *DailyParams:
		// We are consolidating instances into a daily DB.
		destination, err = metabase.NewDailyDatabase(cp.App, cp.YYYYMMDD)
	case *MonthlyParams:
		destination, err = metabase.NewMonthlyDatabase(cp.App, cp.YearNumber, cp.MonthNumber)
	case *YearlyParams:
		destination, err = metabase.NewYearlyDatabase(cp.App, cp.YearNumber)
	case *FullParams:
		destination, err = metabase.NewFullDatabase(cp.App)
	default:
		return errors.New("cannot consolidation unknown type")
	}
	if err != nil {
		return err
	}
	// Open the database we created.
	err = destination.Open(metabase.ReplaceExistingOrCreateNew)
	if err != nil {
		return errors.New("could not open archive")
	}
	defer destination.Close()

	// Attach the destination
	attachDestinationQ := fmt.Sprintf(`ATTACH '%s' AS destination`,
		destination.FullFilename())
	_, err = inMem.Exec(attachDestinationQ)
	if err != nil {
		return err
	}

	// Copy the following tables with the given columns
	// FIXME: these want to become some kind of constantls
	var allTables = []struct {
		table   string
		columns string
	}{
		{"event", "inserted, key_id, cluster, tags, data"},
		{"summary", "inserted, key_id, operation, tags, data"},
	}
	// Normally, string interpolation in a query is *very, very bad*.
	// Here, these are values that we control. The user does not. Hence, we'll
	// build the query to copy from the globbed database into the destination.
	for _, tt := range allTables {
		copyQ := fmt.Sprintf(
			`INSERT INTO destination.%s (%s) SELECT %s FROM read_duckdb('%s', table_name='%s')`,
			tt.table, tt.columns, tt.columns, cp.Glob(), tt.table)

		// Copy the table.
		_, err = inMem.Exec(copyQ)
		if err != nil {
			return err
		}
	}
	return nil
}

func countFiles(glob string) int {
	matches, err := filepath.Glob(glob)
	if err != nil {
		return 0
	}
	return len(matches)
}
