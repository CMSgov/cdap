package metabase

import (
	"database/sql"

	"github.com/navapbc/its-log/internal/types"
)

// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
// DAILY
// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
type DailyDatabase struct {
	database *Database
	YYYYMMDD string
}

func NewDailyDatabase(app types.App, yyyymmdd string) (*DailyDatabase, error) {

	M, err := NewMetabase(ArchiveLocation, app.AppId)
	if err != nil {
		return nil, err
	}
	I := &DailyDatabase{
		database: &Database{
			app:  app,
			meta: M,
		},
		YYYYMMDD: yyyymmdd,
	}
	return I, nil
}

func (DB *DailyDatabase) SetDB(db *sql.DB) {
	DB.database.meta.SetDB(db)
}

func (DD *DailyDatabase) GetDB() *sql.DB {
	return DD.database.meta.GetDB()
}

// By implementing the entire interface, we can pass this anywhere
// a type of IMetabase is expected.
func (DD *DailyDatabase) FullFilename() string {

}

func (DD *DailyDatabase) Open(mode MetabaseOpenMode) error {
	return open(DD, mode)
}

func (DD *DailyDatabase) Close() error {
	return close(DD)
}

func (DD *DailyDatabase) Flush() error {
	return flush(DD)
}

func (DD *DailyDatabase) Delete() error {
	return delete(DD)
}

func (DD *DailyDatabase) Lock(msg string) {
	DD.database.meta.Lock(msg)
}

func (DD *DailyDatabase) Unlock(msg string) {
	DD.database.meta.Unlock(msg)
}
