package metabase

import (
	"database/sql"
	"fmt"
	"path"
)

// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
// MONTHLY
// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
type MonthlyDatabase struct {
	database    *Database
	YYYY        int
	MonthNumber int
}

func NewMonthlyDatabase(app App, year int, month int) (*MonthlyDatabase, error) {

	M, err := NewMetabase(ArchiveLocation, app.AppId)
	if err != nil {
		return nil, err
	}
	I := &MonthlyDatabase{
		database: &Database{
			app:  app,
			meta: M,
		},
		YYYY:        year,
		MonthNumber: month,
	}
	return I, nil
}

func (DB *MonthlyDatabase) SetDB(db *sql.DB) {
	DB.database.meta.SetDB(db)
}

func (DB *MonthlyDatabase) GetDB() *sql.DB {
	return DB.database.meta.GetDB()
}

// By implementing the entire interface, we can pass this anywhere
// a type of IMetabase is expected.
func (DB *MonthlyDatabase) FullFilename() string {
	filename := fmt.Sprintf("%s_monthly_%d-%d.%s",
		DB.database.app.AppId,
		DB.YYYY,
		DB.MonthNumber,
		DUCKDB_EXTENSION,
	)
	return path.Join(DB.database.meta.path, filename)
}

func (DB *MonthlyDatabase) Open(mode MetabaseOpenMode) error {
	return open(DB, mode)
}

func (DB *MonthlyDatabase) Close() error {
	return DB.database.meta.Close()
}

func (DB *MonthlyDatabase) Flush() error {
	return DB.database.meta.Flush()
}

func (DB *MonthlyDatabase) Delete() error {
	return delete(DB)
}

func (DB *MonthlyDatabase) Lock(msg string) {
	DB.database.meta.Lock(msg)
}

func (DB *MonthlyDatabase) Unlock(msg string) {
	DB.database.meta.Unlock(msg)
}
