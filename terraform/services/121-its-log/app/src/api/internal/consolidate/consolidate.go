package consolidate

import (
	"errors"
	"fmt"

	"github.com/navapbc/its-log/internal/metabase"
)

func Consolidate(cp ConsolidationParams) error {
	// Get an in-memory database to attach things to.
	inMem, err := GetInMemoryDB()
	if err != nil {
		return err
	}

	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	var destination metabase.IMetabase
	switch cp := cp.(type) {
	case *DailyParams:
		// We are consolidating instances into a daily DB.
		destination, err = metabase.NewDailyDatabase(cp.App, cp.YYYYMMDD)
		if err != nil {
			return err
		}
		err = destination.Open(metabase.ReplaceExistingOrCreateNew)
		if err != nil {
			return errors.New("could not open archive")
		}
	default:
		return errors.New("cannot consolidation unknown type")
	}

	// Attach the destination
	attachDestinationQ := fmt.Sprintf(`ATTACH '%s' AS destination`,
		destination.FullFilename())
	_, err = inMem.Exec(attachDestinationQ)
	if err != nil {
		return err
	}

	var table string
	var columns string
	switch cp.GetKind() {
	case EventsConsolidation:
		table = "event"
		columns = "inserted, key_id, cluster, tags, data"
	case SummaryConsolidation:
		table = "summary"
		columns = "inserted, key_id, operation, tags, data"
	default:
		return errors.New("unknown table for consolidation")
	}

	// Normally, string interpolation in a query is *very, very bad*.
	// Here, these are values that we control. The user does not. Hence, we'll
	// build the query to copy from the globbed database into the destination.
	copyQ := fmt.Sprintf(
		`INSERT INTO destination.%s (%s) SELECT %s FROM read_duckdb('%s', table_name='%s')`,
		table, columns, columns, cp.Glob(), table)

	// Copy the table.
	_, err = inMem.Exec(copyQ)
	if err != nil {
		return err
	}
	inMem.Close()
	destination.Close()

	return nil
}
