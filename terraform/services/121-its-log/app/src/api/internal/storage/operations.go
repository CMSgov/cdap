package storage

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"regexp"
	"strings"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type StoredSql int

const (
	Schema StoredSql = iota
	Endpoint
)

const SQL_NAMED_PARAM_SYMBOL = "$"

// var activeStorageConnections StorageMap = make(StorageMap, 0)

func DoesDBExist(pathArr []string) bool {
	dbPath := path.Join(pathArr...)

	_, err := os.Stat(dbPath)
	// If we don't get an error, the file exists.
	if err == nil {
		return true
	} else if errors.Is(err, os.ErrNotExist) {
		// If there is an error, we'll log and return.
		zap.L().Info("file does not exist",
			zap.String("filename", dbPath))
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

// Helper for the endpoints and other uses across the codebase
// This is the preferred entrypoint to the Storage API.
func SetupDB(appId string, date string) (*Storage, error) {
	s, err := NewStorage(appId)
	if err != nil {
		return nil, err
	}
	err = s.SetDateYMD(date)
	if err != nil {
		return nil, err
	}

	err = s.InitDB()
	if err != nil {
		log.Println("storage init error: " + err.Error())
		panic(err)
	}

	zap.L().Debug("SetupDB new storage created",
		zap.String("app_id", appId), zap.String("date", date))
	return s, nil
}

func NewStorage(appId string) (*Storage, error) {

	// Create DB
	s := &Storage{
		AppId: appId,
	}
	s.ILTime = types.NewILTimeToday()
	s.db = nil

	return s, nil
}

// func getDuckDBConnector(dbPath string, bootQueries []string) (*duckdb.Connector, context.Context, error) {
// 	ctx := context.Background()

// 	c, err := duckdb.NewConnector(dbPath, func(execer driver.ExecerContext) error {
// 		// https://duckdb.org/docs/current/configuration/overview
// 		for _, query := range bootQueries {
// 			zap.L().Debug("connector query", zap.String("query", query))
// 			_, err := execer.ExecContext(ctx, query, nil)
// 			if err != nil {
// 				zap.L().Error("new connector error", zap.Error(err))
// 				return err
// 			}
// 		}
// 		return nil
// 	})
// 	return c, ctx, err
// }

func ConstructDBFilenameAndPath(appId string, date string) (string, []string) {
	// Compute filename based on date and app ID
	fname := fmt.Sprintf("%s_%s.duckdb", appId, date)
	path := []string{viper.GetString("storage.path"), fname}
	return fname, path
}

func (s *Storage) InitDB() error {
	s.Filename, s.Path = ConstructDBFilenameAndPath(s.AppId, s.YYYYMMDD())
	// Don't re-initialize a database
	if s.db != nil {
		zap.L().Debug("choosing not to re-initialize the database")
		return nil
	}

	dbPath := path.Join(s.Path...)
	var err error
	// We need the raw context connector for appenders.
	// s.db, s.connector, s.Context, err = openDatabase(dbPath)
	db, err := sql.Open("duckdb", dbPath)
	if err != nil {
		return err
	}
	s.db = db

	s.Schema = NewEmbedSql("schema")
	s.Schema.Init(s.db)
	s.Endpoints = NewEmbedSql("endpoints")
	s.Endpoints.Init(s.db)

	err = s.InitTables()

	// If the DB file exists, return now.
	if DoesDBExist(s.Path) {
		zap.L().Debug("file exists, initialized")
		return nil
	}

	// This forces the creation of an empty file.
	s.Close()

	zap.L().Debug("database is closed")
	//s.db, s.connector, s.Context, err = openDatabase(dbPath)
	db, err = sql.Open("duckdb", dbPath)
	if err != nil {
		panic(err)
	}
	s.db = db
	zap.L().Debug("database is open")

	return nil
}

func (s *Storage) ExecNoLock(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {

	switch kind {
	case Schema:
		res, err := s.Schema.Exec(name, make([]any, 0))
		return res, err
	case Endpoint:
		if _, ok := s.Endpoints.Files[name]; ok {
			args, err := s.PrepareNamedArgs(name, params)
			if err != nil {
				zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
				return nil, err
			}
			// Get the SQL
			theSql := s.Endpoints.Files[name]
			res, err := s.db.Exec(theSql, args...)
			if err != nil {
				zap.L().Error("ExecContext failure",
					zap.String("name", name),
					zap.Any("params", params),
					zap.Any("args", args),
					zap.Error(err))
			}
			return res, err
		} else {
			return nil, fmt.Errorf("could not find stored SQL for %s", name)
		}
	default:
		zap.L().Error("Exec: unknown kind of stored SQL",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
		return nil, errors.New("unknown kind of stored SQL")
	}

	// Unreachable via gopls
}

func (s *Storage) Exec(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {
	s.Lock("Exec")
	res, err := s.ExecNoLock(kind, name, params)
	s.Flush()
	s.Unlock("Exec")
	return res, err
}

func (s *Storage) Query(kind StoredSql, name string, params EmbedParamMap) (*sql.Rows, error) {
	var err error
	var res *sql.Rows

	err = errors.New("unknown kind of stored SQL")

	s.Lock("Query")
	switch kind {
	case Schema:
		msg := "cannot query a schema"
		zap.L().Error(msg)
		err = errors.New(msg)
	case Endpoint:
		args, err := s.PrepareNamedArgs(name, params)
		if err != nil {
			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
			s.Unlock("Query")
			return nil, err
		}
		res, err = s.Endpoints.Query(name, args)
	default:
		zap.L().Error("Query: unknown kind of stored SQL",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
	}
	s.Unlock("Query")

	return res, err
}

func (s *Storage) QueryRow(kind StoredSql, name string, params EmbedParamMap) *sql.Row {
	var row *sql.Row
	s.Lock("QueryRow")
	switch kind {
	case Endpoint:
		args, err := s.PrepareNamedArgs(name, params)
		if err != nil {
			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
			s.Unlock("QueryRow")
			return nil
		}
		row = s.db.QueryRow(s.Endpoints.Files[name], args...)
	default:
		zap.L().Error("Query: unknown kind of stored sql",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
	}
	s.Unlock("QueryRow")

	return row
}

func (s *Storage) InitTables() error {
	// Create tables
	_, err := s.Exec(Schema, "schema", nil)
	if err != nil {
		return err
	}

	return nil
}

func (s *Storage) Close() {
	zap.L().Info("database closed via s.Close()")
	if s.connector != nil {
		s.connector.Close()
		s.connector = nil
	}
	if s.appender != nil {
		s.appender.Close()
		s.appender = nil
	}
	if s.Context != nil {
		s.Context.Done()
		s.Context = nil
	}
	if s.db != nil {
		s.db.Close()
		s.db = nil
	}
	// If the DB is closed, kill the entire storage pointer.
	// s = nil
}

func (s *Storage) Flush() {
	// This flushes any outstanding actions/transactions on the DuckDB.
	// Good to do before closing the file or doing any operations on the DB file itself.
	_, err := s.db.Exec("CHECKPOINT;")
	if err != nil {
		// Try once more, after trying to open the database.
		zap.L().Info("failed to checkpoint; retrying")
		if DoesDBExist(s.Path) {
			// It exists. Lets try to open it. For some reason, we were closed.
			// s.db, s.connector, s.Context, err = openDatabase(path.Join(s.Path...))
			db, err := sql.Open("duckdb", path.Join(s.Path...))
			if err != nil {
				msg := "tried to reopen the database, could not"
				zap.L().Error(msg, zap.Error(err))
				panic(msg)
			}
			s.db = db
			zap.L().Info("had to reopen the datbase",
				zap.String("app_id", s.AppId),
				zap.String("filename", s.Filename),
				zap.String("date", s.YYYYMMDD()))
			_, err = s.db.Exec("CHECKPOINT;")
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

func (s *Storage) GetDB() *sql.DB {
	return s.db
}

func (s *Storage) Lock(location string) {
	zap.L().Debug("== Lock ==",
		zap.String("app_id", s.AppId),
		zap.String("date", s.YYYYMMDD()),
		zap.String("location", location))
	s.lock.Lock()

}

func (s *Storage) Unlock(location string) {

	zap.L().Debug("== Unlock ==",
		zap.String("app_id", s.AppId),
		zap.String("date", s.YYYYMMDD()),
		zap.String("location", location))
	s.lock.Unlock()
}

func (s *Storage) Delete() {
	s.Flush()
	s.db.Close()
	path := path.Join(viper.GetString("storage.path"), s.Filename)
	log.Printf("Deleting database: %s", path)
	os.Remove(path)
}

func (s *Storage) GetEtlFromDb(name string) (EtlRow, error) {
	raw := s.QueryRow(Endpoint,
		"get_etl",
		EmbedParamMap{"name": name})

	// var name, kind, body, lastRun string
	//err := row.Scan(&name, &kind, &body, &lastRun)
	var etlRow EtlRow
	err := raw.Scan(&etlRow.Name, &etlRow.Kind, &etlRow.Body)

	if err != nil {
		msg := "could not get etl from db"
		zap.L().Error(msg,
			zap.String("etl_name", name),
			zap.Error(err),
		)
		return EtlRow{}, errors.New(msg)
	}
	return etlRow, nil
}

func GenerateNamedArgs(theSql string, params EmbedParamMap) ([]any, error) {
	// We now are going to figure out which named params are present in the SQL.
	// That way, we only create named args for things that are present.
	// The SQL engine does not like when you pass named paramters that do not exist in the SQL.
	// E.g. we cannot provide more names than exist.
	re := regexp.MustCompile(`\` + SQL_NAMED_PARAM_SYMBOL + `([a-zA-Z0-9_]+)`)
	matches := re.FindAllString(theSql, -1)

	// And, check everything we found in the SQL is in the params
	named := make([]any, 0)

	for _, arg := range matches {
		trimmed := strings.Replace(arg, "$", "", 1)
		if _, ok := params[trimmed]; !ok {
			zap.L().Error("found in SQL but not in params",
				zap.String("trimmed", trimmed))
			return nil, fmt.Errorf("%s found in SQL but not in params", trimmed)
		} else {
			named = append(named, sql.Named(trimmed, params[trimmed]))
		}
	}
	return named, nil
}

// Consumes the name of embedded SQL and a parameter map.
// Finds the named params in the SQL (which must begin with $_)
// and looks up the name in the map, returning a list of sql.NamedArgs
// matching the variables needed to execute the SQL
func (s *Storage) PrepareNamedArgs(name string, params EmbedParamMap) ([]any, error) {
	// Look for the named params expected in the SQL
	var theSql string
	if _, ok := s.Endpoints.Files[name]; !ok {
		etlRow, err := s.GetEtlFromDb(name)
		if err != nil {
			return nil, fmt.Errorf("could not prepare args for %s; not found", name)
		}
		theSql = etlRow.Body
	} else {
		theSql = s.Endpoints.Files[name]
	}
	named, err := GenerateNamedArgs(theSql, params)
	if err != nil {
		return nil, err
	}
	return named, nil
}

func (s *Storage) GetMaxId(etl string, params EmbedParamMap) (int64, error) {
	// The appender must supply all columns.
	// Therefore, we need to provide the PK, which is an incrementing integer.
	// Flushes are strictly sequential, because of the architecture of its-log.
	// Therefore, it should be safe to get the id and then do the inserts. Two buffer
	// flushes cannot collide; the channel semantics protect this.
	var max_id int64
	args, err := s.PrepareNamedArgs(etl, params)
	if err != nil {
		zap.L().Error("could not prepare args for GetMaxId", zap.Error(err))
	}
	stmt, err := s.db.Prepare(s.Endpoints.Files[etl])
	if err != nil {
		panic("cannot prepare GetMaxId")
	}
	row := stmt.QueryRow(args...)
	err = row.Scan(&max_id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			zap.L().Debug("GetMaxId nothing in result set; returning 0")
			return 0, nil
		} else {
			zap.L().Error("could not get max for id",
				zap.String("etl", etl), zap.Any("params", params), zap.Error(err))
			return -1, fmt.Errorf("could not get max id")
		}
	}

	return max_id, nil
}
