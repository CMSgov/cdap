package storage

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path"
	"sync"
	"time"

	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type FilesystemLocation int

const (
	Live = iota
	Archive
	Export
)

func (f FilesystemLocation) String() string {
	var names = [...]string{
		Live:    "Live",
		Archive: "Archive",
		Export:  "Export",
	}
	if f > 0 && int(f) < len(names) {
		return names[f]
	} else {
		return "UnknownFilesystemLocation"
	}
}

type MetabaseOpenMode int

const (
	OpenExistingOnly MetabaseOpenMode = iota
	OpenExistingOrCreateNew
	ReplaceExisting
)

type Metabase struct {
	location FilesystemLocation
	path     string
	filename string
	openMode MetabaseOpenMode
	lock     sync.Mutex
	context  context.Context
	db       *sql.DB
}

const DUCKDB_EXTENSION = "duckdb"

func NewMetabase(location FilesystemLocation, filename string) (*Metabase, error) {
	p := "BAD_PATH"
	switch location {
	case Live:
		p = viper.GetString("storage.path")
	case Archive:
		p = viper.GetString("archive.path")
	case Export:
		p = viper.GetString("export.path")
	}
	return &Metabase{
		location: location,
		path:     p,
		filename: filename + "." + DUCKDB_EXTENSION,
	}, nil
}

func (M *Metabase) FullFilename() string {
	return path.Join(M.path, M.filename)
}

func (M *Metabase) CheckExists() bool {
	full := M.FullFilename()
	_, err := os.Stat(full)
	// If we don't get an error, the file exists.
	if err == nil {
		return true
	} else if errors.Is(err, os.ErrNotExist) {
		// If there is an error, we'll log and return.
		zap.L().Info("file does not exist",
			zap.String("filename", full))
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

func (M *Metabase) Lock(location string) {
	zap.L().Debug("== Lock ==",
		zap.String("location", location),
		zap.String("path", M.path),
		zap.String("filename", M.filename),
	)
	M.lock.Lock()
}

func (M *Metabase) Unlock(location string) {
	zap.L().Debug("== Unlock ==",
		zap.String("location", location),
		zap.String("path", M.path),
		zap.String("filename", M.filename),
	)
	M.lock.Unlock()
}

func (M *Metabase) open() error {

	db, err := sql.Open("duckdb", M.FullFilename())
	if err != nil {
		return err
	}
	db.SetMaxIdleConns(0)
	M.db = db
	return nil
}

func touch(filename string) error {
	// If the file does not exist, it will be created
	// os.O_RDONLY will open/create without modifying an existing file
	//        U  G  A
	// 600 = -rw-------
	// We are the only user who needs to be able to read the files
	file, err := os.OpenFile(filename, os.O_RDONLY|os.O_CREATE, 0600)
	if err != nil {
		return err
	}
	file.Close()

	// 2. Update both the access time and modification time to "now"
	now := time.Now()
	err = os.Chtimes(filename, now, now)
	if err != nil {
		return err
	}

	return nil
}

func (M *Metabase) Open(mode MetabaseOpenMode) error {
	M.openMode = mode

	switch mode {
	case OpenExistingOnly:
		if M.CheckExists() {
			zap.L().Info("OpenExistingOnly")
			// fall through to open
		} else {
			return errors.New("database does not exist")
		}
	case OpenExistingOrCreateNew:
		if M.CheckExists() {
			zap.L().Info("OpenExisting")
			// fall through to open
		} else {
			zap.L().Info("CreateNew")
			// fall through; the open call will create
		}
	case ReplaceExisting:
		if M.CheckExists() {
			zap.L().Info("ReplaceIfExists")
			// delete if it exists, and then fall through.
			delErr := M.Delete()
			if delErr != nil {
				return delErr
			}
		} else {
			return errors.New("cannot replace; database does not exist: " + M.FullFilename())
		}
	}

	err := touch(M.FullFilename())
	if err != nil {
		return errors.New("could not touch database: " + err.Error())
	}

	err = M.open()
	if err != nil {
		return errors.New("open and close: " + err.Error())
	}

	if !M.CheckExists() {
		panic("file does not exist")
	}

	return nil
}

func (M *Metabase) Close() error {
	if M.context != nil {
		M.context.Done()
		M.context = nil
	}
	if M.db != nil {
		err := M.db.Close()
		if err != nil {
			return err
		}
		M.db = nil
	}
	// Give it the old college try...
	if M.lock.TryLock() {
		// This means the lock was acquired...
		defer M.Unlock("Close")
	} else {
		// It is locked. Unlock it.
		defer M.Unlock("Close")
	}
	zap.L().Info("database closed via Close()")
	return nil
}

func (M *Metabase) Flush() {
	// This flushes any outstanding actions/transactions on the DuckDB.
	// Good to do before closing the file or doing any operations on the DB file itself.
	_, err := M.db.Exec("CHECKPOINT;")
	if err != nil {
		// Try once more, after trying to open the database.
		zap.L().Info("failed to checkpoint; retrying")
		if M.CheckExists() {
			err := M.Open(OpenExistingOnly)
			if err != nil {
				msg := "tried to reopen the database, could not"
				zap.L().Error(msg, zap.Error(err))
				panic(msg)
			}
			zap.L().Info("had to reopen the datbase",
				zap.String("filename", M.filename),
				zap.String("location", M.location.String()))
			_, err = M.db.Exec("CHECKPOINT;")
			if err != nil {
				msg := "failed to checkpoint twice"
				zap.L().Error(msg, zap.Error(err))
				panic(err)
			}
		} else {
			msg := "could not checkpoint the db"
			zap.L().Error(msg, zap.Error(err))
			panic(msg)
		}
	}
}

func (M *Metabase) Delete() error {
	if M.db != nil {
		M.Flush()
		M.db.Close()
	}
	zap.L().Info("deleting database",
		zap.String("filename", M.FullFilename()))

	err := os.Remove(M.FullFilename())
	if err != nil {
		zap.L().Error("could not delete",
			zap.String("filename", M.filename),
			zap.String("path", M.path))
	}

	if M.CheckExists() {
		return errors.New("failed to delete database")
	}
	return err
}

type Database struct {
	Metabase
	AppId string
	KeyId string
}

type InstanceDatabase struct {
	Database
	InstanceId string
	YYYYMMDD   string
}

type DailyDatabase struct {
	Database
	YYYYMMDD string
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
