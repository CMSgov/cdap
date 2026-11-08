package metabase

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path"
	"sync"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type Lockable struct {
	lock     sync.Mutex
	path     string
	filename string
}

func (L *Lockable) Lock(location string) {
	zap.L().Debug("== Lock ==",
		zap.String("location", location),
		zap.String("path", L.path),
		zap.String("filename", L.filename),
	)
	L.lock.Lock()
}

func (L *Lockable) Unlock(location string) {
	zap.L().Debug("== Unlock ==",
		zap.String("location", location),
		zap.String("path", L.path),
		zap.String("filename", L.filename),
	)
	L.lock.Unlock()
}

type DB struct {
	Context context.Context
	db      *sql.DB
}

type LockableDB struct {
	*Lockable
	database *DB
}

type Metabase struct {
	*LockableDB
	location FilesystemLocation
	openMode MetabaseOpenMode
}

type IMetabase interface {
	SetDB(db *sql.DB)
	GetDB() *sql.DB
	FullFilename() string
	Open(mode MetabaseOpenMode) error
	Close() error
	Flush() error
	Delete() error
	Lock(msg string)
	Unlock(msg string)
}

const DUCKDB_EXTENSION = "duckdb"

// ##     ## ######## ########    ###    ########     ###     ######  ########
// ###   ### ##          ##      ## ##   ##     ##   ## ##   ##    ## ##
// #### #### ##          ##     ##   ##  ##     ##  ##   ##  ##       ##
// ## ### ## ######      ##    ##     ## ########  ##     ##  ######  ######
// ##     ## ##          ##    ######### ##     ## #########       ## ##
// ##     ## ##          ##    ##     ## ##     ## ##     ## ##    ## ##
// ##     ## ########    ##    ##     ## ########  ##     ##  ######  ########

func NewMetabase(location FilesystemLocation, filename string) (*Metabase, error) {
	p := "BAD_PATH"
	switch location {
	case LiveLocation:
		p = viper.GetString("storage.path")
	case ArchiveLocation:
		p = viper.GetString("archive.path")
	case ExportLocation:
		p = viper.GetString("export.path")
	}

	return &Metabase{
		location: location,
		LockableDB: &LockableDB{
			database: &DB{
				Context: context.Background(),
				db:      nil,
			},
			Lockable: &Lockable{
				path:     p,
				filename: filename,
			},
		},
	}, nil
}

func (M *Metabase) SetDB(db *sql.DB) {
	M.database.db = db
}

func (M *Metabase) GetDB() *sql.DB {
	return M.database.db
}

func (M *Metabase) FullFilename() string {
	return path.Join(M.path, M.filename)
}

func CheckExists(im IMetabase) bool {
	full := im.FullFilename()
	_, err := os.Stat(full)
	// If we don't get an error, the file exists.
	if err == nil {
		return true
	} else if errors.Is(err, os.ErrNotExist) {
		return false
	} else {
		// Other errors could have occurred; for example,
		// there could be a disk error. Instead of handling everything,
		// we'll log the error, and indicate we cannot find the file.
		zap.L().Info("unknown error; file effectively does not exist",
			zap.Error(err))
		return false
	}
}

func open(im IMetabase, mode MetabaseOpenMode) error {
	touch := false
	switch mode {
	case OpenExistingOnly:
		if CheckExists(im) {
			zap.L().Info("OpenExistingOnly")
			// fall through to open
		} else {
			return errors.New("database does not exist")
		}
	case OpenExistingOrCreateNew:
		if CheckExists(im) {
			zap.L().Info("OpenExisting")
			// fall through to open
		} else {
			zap.L().Info("CreateNew")
			touch = true
			// fall through; the open call will create
		}
	case CreateNew:
		if CheckExists(im) {
			zap.L().Info("CreateNew")
			return errors.New("cannot open; already exists")
		}
		touch = true
	case ReplaceExisting:
		if CheckExists(im) {
			zap.L().Info("ReplaceIfExists")
			// delete if it exists, and then fall through.
			delErr := im.Delete()
			if delErr != nil {
				return delErr
			}
			touch = true
		} else {
			return errors.New("cannot replace on open; database does not exist: " + im.FullFilename())
		}
	case ReplaceExistingOrCreateNew:
		if CheckExists(im) {
			zap.L().Info("ReplaceIfExists")
			// delete if it exists, and then fall through.
			delErr := im.Delete()
			if delErr != nil {
				return delErr
			}
			touch = true
		}
		// fall through
	}

	if touch {
		db, err := sql.Open("duckdb", im.FullFilename())
		if err != nil {
			return errors.New("open: " + err.Error())
		}
		db.SetMaxIdleConns(0)
		im.SetDB(db)
		db.Close()

	}
	db, err := sql.Open("duckdb", im.FullFilename())
	if err != nil {
		return errors.New("open: " + err.Error())
	}
	db.SetMaxIdleConns(0)
	im.SetDB(db)
	// Create the tables.
	_, err = Exec(im, EmbeddedSchema.Files["schema"], EmbedParamMap{})
	if err != nil {
		return err
	}

	if !CheckExists(im) {
		return errors.New("file does not exist after open")
	}

	return err
}

func (M *Metabase) Open(mode MetabaseOpenMode) error {
	M.openMode = mode
	return open(M, mode)
}

func (M *Metabase) Close() error {
	if M.database.Context != nil {
		M.database.Context.Done()
		M.database.Context = nil
	}
	if M.database.db != nil {
		err := M.database.db.Close()
		if err != nil {
			return err
		}
		M.database.db = nil
	}
	// Give it the old college try...
	// In theory, this could cause a race.
	// if M.lock.TryLock() {
	// 	// This means the lock was acquired...
	// 	defer M.Unlock("Was Not Locked")
	// } else {
	// 	// It is locked. Unlock it.
	// 	defer M.Unlock("Lock Malingering")
	// }

	zap.L().Info("database closed via Close()")
	return nil
}

func (M *Metabase) Flush() error {
	// This flushes any outstanding actions/transactions on the DuckDB.
	// Good to do before closing the file or doing any operations on the DB file itself.
	_, err := M.database.db.Exec("CHECKPOINT;")
	if err != nil {
		return err
	}
	return nil
}

func delete(im IMetabase) error {
	if err := im.Close(); err != nil {
		return err
	}
	err := os.Remove(im.FullFilename())
	if err != nil {
		zap.L().Error("could not delete",
			zap.String("filename", im.FullFilename()))
	}

	if CheckExists(im) {
		return errors.New("failed to delete database")
	}
	return err
}

func (M *Metabase) Delete() error {
	return delete(M)
}

// /////////////
type Database struct {
	meta *Metabase
	app  App
}

func NewDatabase(app App, M *Metabase) *Database {
	return &Database{
		app:  app,
		meta: M,
	}
}

// #### ##    ##  ######  ########    ###    ##    ##  ######  ######## ########     ###    ########    ###    ########     ###     ######  ########
//	##  ###   ## ##    ##    ##      ## ##   ###   ## ##    ## ##       ##     ##   ## ##      ##      ## ##   ##     ##   ## ##   ##    ## ##
//	##  ####  ## ##          ##     ##   ##  ####  ## ##       ##       ##     ##  ##   ##     ##     ##   ##  ##     ##  ##   ##  ##       ##
//	##  ## ## ##  ######     ##    ##     ## ## ## ## ##       ######   ##     ## ##     ##    ##    ##     ## ########  ##     ##  ######  ######
//	##  ##  ####       ##    ##    ######### ##  #### ##       ##       ##     ## #########    ##    ######### ##     ## #########       ## ##
//	##  ##   ### ##    ##    ##    ##     ## ##   ### ##    ## ##       ##     ## ##     ##    ##    ##     ## ##     ## ##     ## ##    ## ##
// #### ##    ##  ######     ##    ##     ## ##    ##  ######  ######## ########  ##     ##    ##    ##     ## ########  ##     ##  ######  ########

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

// ########     ###    #### ##       ##    ## ########     ###    ########    ###    ########     ###     ######  ########
// ##     ##   ## ##    ##  ##        ##  ##  ##     ##   ## ##      ##      ## ##   ##     ##   ## ##   ##    ## ##
// ##     ##  ##   ##   ##  ##         ####   ##     ##  ##   ##     ##     ##   ##  ##     ##  ##   ##  ##       ##
// ##     ## ##     ##  ##  ##          ##    ##     ## ##     ##    ##    ##     ## ########  ##     ##  ######  ######
// ##     ## #########  ##  ##          ##    ##     ## #########    ##    ######### ##     ## #########       ## ##
// ##     ## ##     ##  ##  ##          ##    ##     ## ##     ##    ##    ##     ## ##     ## ##     ## ##    ## ##
// ########  ##     ## #### ########    ##    ########  ##     ##    ##    ##     ## ########  ##     ##  ######  ########
type DailyDatabase struct {
	database *Database
	YYYYMMDD string
}

func NewDailyDatabase(app App, yyyymmdd string) (*DailyDatabase, error) {

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
	filename := fmt.Sprintf("%s_daily_%s.%s",
		DD.database.app.AppId,
		DD.YYYYMMDD,
		DUCKDB_EXTENSION,
	)
	return path.Join(DD.database.meta.path, filename)
}

func (DD *DailyDatabase) Open(mode MetabaseOpenMode) error {
	return open(DD, mode)
}

func (DD *DailyDatabase) Close() error {
	return DD.database.meta.Close()
}

func (DD *DailyDatabase) Flush() error {
	return DD.database.meta.Flush()
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

type WeeklyDatabase struct {
	Database
	YYYY       int
	WeekNumber int
}

type MonthlyDatabase struct {
	Database
	YYYY        int
	MonthNumber int
}
