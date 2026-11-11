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
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type Metabase struct {
	config   MetaParams
	Kind     MetaType
	lock     sync.Mutex
	path     string
	filename string
	Context  context.Context
	db       *sql.DB
	location FilesystemLocation
	openMode MetabaseOpenMode
}

const DUCKDB_EXTENSION = "duckdb"

///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
// METABASE
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////

func getPath(kind MetaType) string {
	p := "BAD_PATH"
	switch kind {
	case Instance:
		p = viper.GetString("storage.path")
	case Daily:
		p = viper.GetString("archive.path")
	case Monthly:
		p = viper.GetString("archive.path")
	case Yearly:
		p = viper.GetString("archive.path")
	case Full:
		p = viper.GetString("archive.path")
	default:
		panic("cannot get path for invalid MetaType")
	}
	return p
}
func NewMetabase(kind MetaType, filename string) (*Metabase, error) {

	return &Metabase{
		Kind:     kind,
		Context:  context.Background(),
		db:       nil,
		path:     getPath(kind),
		filename: filename,
	}, nil
}

func NewInstanceDatabase(config MetaParams) (*Metabase, error) {
	config.(*InstanceParams).instanceId = viper.GetString("instance.id")
	return &Metabase{
		Kind:    Instance,
		Context: context.Background(),
		db:      nil,
		path:    getPath(Instance),
		config:  config,
	}, nil
}

func NewDailyDatabase(config MetaParams) (*Metabase, error) {
	return &Metabase{
		Kind:    Daily,
		Context: context.Background(),
		db:      nil,
		path:    getPath(Daily),
		config:  config,
	}, nil
}

func NewMonthlyDatabase(config MetaParams) (*Metabase, error) {
	return &Metabase{
		Kind:    Monthly,
		Context: context.Background(),
		db:      nil,
		path:    getPath(Monthly),
		config:  config,
	}, nil
}

func NewYearlyDatabase(config MetaParams) (*Metabase, error) {
	return &Metabase{
		Kind:    Yearly,
		Context: context.Background(),
		db:      nil,
		path:    getPath(Yearly),
		config:  config,
	}, nil
}

func NewFullDatabase(config MetaParams) (*Metabase, error) {
	return &Metabase{
		Kind:    Full,
		Context: context.Background(),
		db:      nil,
		path:    getPath(Full),
		config:  config,
	}, nil
}

func (M *Metabase) setDB(db *sql.DB) {
	M.db = db
}

func (M *Metabase) GetDB() *sql.DB {
	return M.db
}

func (M *Metabase) GetContext() context.Context {
	return M.Context
}

func (M *Metabase) ContextDone() {
	M.Context.Done()
}

func (M *Metabase) FullFilename() string {
	switch M.Kind {
	case Instance:
		filename := fmt.Sprintf("%s_instance_%s_%s.%s",
			M.config.GetApp().AppId,
			M.config.(*InstanceParams).instanceId,
			M.config.(*InstanceParams).YYYYMMDD,
			DUCKDB_EXTENSION,
		)
		return path.Join(M.path, filename)
	case Daily:
		filename := fmt.Sprintf("%s_daily_%s.%s",
			M.config.GetApp().AppId,
			M.config.(*DailyParams).YYYYMMDD,
			DUCKDB_EXTENSION,
		)
		return path.Join(M.path, filename)
	case Monthly:
		filename := fmt.Sprintf("%s_monthly_%d_%02d.%s",
			M.config.GetApp().AppId,
			M.config.(*MonthlyParams).YearNumber,
			M.config.(*MonthlyParams).MonthNumber,
			DUCKDB_EXTENSION,
		)
		return path.Join(M.path, filename)
	case Yearly:
		filename := fmt.Sprintf("%s_yearly_%d.%s",
			M.config.GetApp().AppId,
			M.config.(*YearlyParams).YearNumber,
			DUCKDB_EXTENSION,
		)
		return path.Join(M.path, filename)
	case Full:
		filename := fmt.Sprintf("%s_full.%s",
			M.config.GetApp().AppId,
			DUCKDB_EXTENSION,
		)
		return path.Join(M.path, filename)
	default:
		panic("cannot get filename of unknown MetabaseKind")
	}

}

func (M *Metabase) CheckExists() bool {
	full := M.FullFilename()
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

func (M *Metabase) Lock(loc string) {
	zap.L().Debug("== LOCK ==",
		zap.String("location", loc),
		zap.String("db", M.FullFilename()))
	M.lock.Lock()
}

func (M *Metabase) Unlock(loc string) {
	zap.L().Debug("== UNLOCK ==",
		zap.String("location", loc),
		zap.String("db", M.FullFilename()))
	M.lock.Unlock()
}

func (M *Metabase) Open(mode MetabaseOpenMode) error {
	touch := false
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
			touch = true
			// fall through; the open call will create
		}
	case CreateNew:
		if M.CheckExists() {
			zap.L().Info("CreateNew")
			return errors.New("cannot open; already exists")
		}
		touch = true
	case ReplaceExisting:
		if M.CheckExists() {
			zap.L().Info("ReplaceIfExists")
			// delete if it exists, and then fall through.
			delErr := M.Delete()
			if delErr != nil {
				return delErr
			}
			touch = true
		} else {
			return errors.New("cannot replace on open; database does not exist: " + M.FullFilename())
		}
	case ReplaceExistingOrCreateNew:
		if M.CheckExists() {
			zap.L().Info("ReplaceIfExists")
			// delete if it exists, and then fall through.
			delErr := M.Delete()
			if delErr != nil {
				return delErr
			}
			touch = true
		}
		// fall through
	}

	if touch {
		db, err := sql.Open("duckdb", M.FullFilename())
		if err != nil {
			return errors.New("open: " + err.Error())
		}
		db.SetMaxIdleConns(0)
		M.setDB(db)
		db.Close()

	}
	db, err := sql.Open("duckdb", M.FullFilename())
	if err != nil {
		return errors.New("open: " + err.Error())
	}
	db.SetMaxIdleConns(0)
	M.setDB(db)
	// Create the tables.
	_, err = Exec(M, embedfs.EmbeddedSchema.Files["schema"], embedfs.EmbedParamMap{})
	if err != nil {
		return err
	}

	if !M.CheckExists() {
		return errors.New("file does not exist after open")
	}

	return err
}

func (M *Metabase) Close() error {
	if M.GetDB() != nil {
		err := M.GetDB().Close()
		if err != nil {
			return err
		}
		zap.L().Info("database closed via Close()")
	} else {
		zap.L().Debug("not closing, DB was nil")
	}
	return nil
}

func (M *Metabase) Flush() error {
	if M.GetDB() != nil {
		// This flushes any outstanding actions/transactions on the DuckDB.
		// Good to do before closing the file or doing any operations on the DB file itself.
		_, err := M.GetDB().Exec("CHECKPOINT;")
		if err != nil {
			return err
		}
	}
	return nil
}

func (M *Metabase) Delete() error {
	if M.GetDB() != nil {
		if err := M.Close(); err != nil {
			return err
		}
		err := os.Remove(M.FullFilename())
		if err != nil {
			zap.L().Error("could not delete",
				zap.String("filename", M.FullFilename()))
			return err
		}

		if M.CheckExists() {
			return errors.New("failed to delete database")
		}
	}
	return nil
}
