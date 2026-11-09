package metabase

import (
	"database/sql"
	"fmt"
	"path"
)

// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
// FULL
// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////

type FullDatabase struct {
	database *Database
}

func NewFullDatabase(app App) (*FullDatabase, error) {

	M, err := NewMetabase(ArchiveLocation, app.AppId)
	if err != nil {
		return nil, err
	}
	I := &FullDatabase{
		database: &Database{
			app:  app,
			meta: M,
		},
	}
	return I, nil
}

func (DB *FullDatabase) SetDB(db *sql.DB) {
	DB.database.meta.SetDB(db)
}

func (DB *FullDatabase) GetDB() *sql.DB {
	return DB.database.meta.GetDB()
}

// By implementing the entire interface, we can pass this anywhere
// a type of IMetabase is expected.
func (DB *FullDatabase) FullFilename() string {
	filename := fmt.Sprintf("%s_full.%s",
		DB.database.app.AppId,
		DUCKDB_EXTENSION,
	)
	return path.Join(DB.database.meta.path, filename)
}

func (DB *FullDatabase) Open(mode MetabaseOpenMode) error {
	return open(DB, mode)
}

func (DB *FullDatabase) Close() error {
	return DB.database.meta.Close()
}

func (DB *FullDatabase) Flush() error {
	return DB.database.meta.Flush()
}

func (DB *FullDatabase) Delete() error {
	return delete(DB)
}

func (DB *FullDatabase) Lock(msg string) {
	DB.database.meta.Lock(msg)
}

func (DB *FullDatabase) Unlock(msg string) {
	DB.database.meta.Unlock(msg)
}
