package metabase

import (
	"database/sql"
	"fmt"
	"path"

	"github.com/navapbc/its-log/internal/types"
)

// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
// YEARLY
// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////

type YearlyDatabase struct {
	database *Database
	YYYY     int
}

func NewYearlyDatabase(app types.App, year int) (*YearlyDatabase, error) {

	M, err := NewMetabase(ArchiveLocation, app.AppId)
	if err != nil {
		return nil, err
	}
	I := &YearlyDatabase{
		database: &Database{
			app:  app,
			meta: M,
		},
		YYYY: year,
	}
	return I, nil
}

func (DB *YearlyDatabase) SetDB(db *sql.DB) {
	DB.database.meta.SetDB(db)
}

func (DB *YearlyDatabase) GetDB() *sql.DB {
	return DB.database.meta.GetDB()
}

// By implementing the entire interface, we can pass this anywhere
// a type of IMetabase is expected.
func (DB *YearlyDatabase) FullFilename() string {
	filename := fmt.Sprintf("%s_yearly_%d.%s",
		DB.database.app.AppId,
		DB.YYYY,
		DUCKDB_EXTENSION,
	)
	return path.Join(DB.database.meta.path, filename)
}

func (DB *YearlyDatabase) Open(mode MetabaseOpenMode) error {
	return open(DB, mode)
}

func (DB *YearlyDatabase) Close() error {
	return DB.database.meta.Close()
}

func (DB *YearlyDatabase) Flush() error {
	return DB.database.meta.Flush()
}

func (DB *YearlyDatabase) Delete() error {
	return delete(DB)
}

func (DB *YearlyDatabase) Lock(msg string) {
	DB.database.meta.Lock(msg)
}

func (DB *YearlyDatabase) Unlock(msg string) {
	DB.database.meta.Unlock(msg)
}
