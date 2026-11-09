package metabase

import (
	"database/sql"
	"fmt"
	"path"

	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
)

// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
// INSTANCE
// /////////////////////////////////////////////////////////////////////////
// /////////////////////////////////////////////////////////////////////////
type InstanceDatabase struct {
	database   *Database
	InstanceId string
	YYYYMMDD   string
}

func NewInstanceDatabase(app App) (*InstanceDatabase, error) {

	M, err := NewMetabase(LiveLocation, app.AppId)
	if err != nil {
		return nil, err
	}
	I := &InstanceDatabase{
		database:   NewDatabase(app, M),
		InstanceId: viper.GetString("instance.id"),
		YYYYMMDD:   types.NewYYYYMMDD().String(),
	}
	return I, nil
}

func (I *InstanceDatabase) SetDB(db *sql.DB) {
	if I.database == nil {
		panic("InstanceDatabase database is nil")
	}
	if I.database.meta == nil {
		panic("InstanceDatabase meta is nil")
	}
	if I.database.meta.database == nil {
		panic("InstanceDatabase meta is nil")
	}
	I.database.meta.database.db = db
}

func (I *InstanceDatabase) GetDB() *sql.DB {
	return I.database.meta.GetDB()
}

// By implementing the entire interface, we can pass this anywhere
// a type of IMetabase is expected.
func (I *InstanceDatabase) FullFilename() string {
	filename := fmt.Sprintf("%s_instance_%s_%s.%s",
		I.database.app.AppId,
		viper.GetString("instance.id"),
		types.NewYYYYMMDD().String(),
		DUCKDB_EXTENSION,
	)
	return path.Join(I.database.meta.path, filename)
}

func (I *InstanceDatabase) Open(mode MetabaseOpenMode) error {
	return open(I, mode)
}

func (I *InstanceDatabase) Close() error {
	return I.database.meta.Close()
}

func (I *InstanceDatabase) Flush() error {
	return I.database.meta.Flush()
}

func (I *InstanceDatabase) Delete() error {
	return delete(I)
}

func (I *InstanceDatabase) Lock(msg string) {
	I.database.meta.Lock(msg)
}

func (I *InstanceDatabase) Unlock(msg string) {
	I.database.meta.Unlock(msg)
}
