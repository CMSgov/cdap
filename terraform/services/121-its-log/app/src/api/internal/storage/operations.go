package storage

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"regexp"
	"strings"

	"github.com/duckdb/duckdb-go/v2"
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

var activeStorageConnections StorageMap = make(StorageMap, 0)

func DoesDBExist(pathArr []string) bool {
	dbPath := path.Join(pathArr...)

	_, err := os.Stat(dbPath)
	// If we don't get an error, the file exists.
	if err == nil {
		return true
	}
	// If there is an error, we'll log and return.
	if errors.Is(err, os.ErrNotExist) {
		zap.L().Info("file does not exist",
			zap.String("filename", dbPath))
		return false
	}

	// Other errors could have occurred; for example,
	// there could be a disk error. Instead of handling everything,
	// we'll log the error, and indicate we cannot find the file.
	zap.L().Info("unknown error; file effectively does not exist",
		zap.Error(err))
	return false
}

func ReuseStorage(appId string, date string) (*Storage, error) {
	// Did we store it in the map?
	// If so, return it. We want these to be persistent for the session

	// FIXME: This does not show up often, but if this pattern starts to appear
	// in multiple places, we should abstract it away. Some kind of "date sanitization"
	// that handles the special cases of "today" and "yesterday".
	date, err := types.SanitizeDate(date)
	if err != nil {
		return nil, err
	}

	if s, ok := activeStorageConnections[appId+date]; ok {
		zap.L().Debug("ReuseStorage",
			zap.String("app_id", appId),
			zap.String("formatted_date", date))
		// Before returning, let's make sure that the
		// database file is still there. DuckDB can have some
		// confusing tmp behaviors in situations where the connection
		// is open but the file "disappears." This should not be possible
		// in production; we can force it locally in a containerized env.
		// We're going to panic if it happens.
		// https://stackoverflow.com/questions/78586256/how-to-force-duckdb-to-reconnect-to-a-file-and-prevent-it-from-remembering-conte
		if !DoesDBExist(s.Path) {
			panic("database file does not exist!")
		}
		return s, nil
	}

	return nil, fmt.Errorf("storage not found for %s", date)
}

// Helper for the endpoints and other uses across the codebase
// This is the preferred entrypoint to the Storage API.
func SetupDB(appId string, date string) (*Storage, error) {

	s, err := ReuseStorage(appId, date)
	if err == nil {
		zap.L().Debug("SetupDB reusing storage",
			zap.String("app_id", appId), zap.String("date", date))
		return s, nil
	}

	// Otherwise, set it up
	s, err = NewStorage(appId)
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

	activeStorageConnections[appId+date] = s

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

func getDuckDBConnector(dbPath string, bootQueries []string) (*duckdb.Connector, error) {
	c, err := duckdb.NewConnector(dbPath, func(execer driver.ExecerContext) error {
		// https://duckdb.org/docs/current/configuration/overview

		for _, query := range bootQueries {
			_, err := execer.ExecContext(context.Background(), query, nil)
			if err != nil {
				return err
			}
		}
		return nil
	})
	return c, err
}

func ConstructDBFilenameAndPath(appId string, date string) (string, []string) {
	// Compute filename based on date and app ID
	fname := fmt.Sprintf("%s_%s.duckdb", appId, date)
	path := []string{viper.GetString("storage.path"), fname}
	return fname, path
}

func OpenDatabase(path string) (*sql.DB, *duckdb.Connector, error) {
	c, err := getDuckDBConnector(path, make([]string, 0))
	if err != nil {
		return nil, nil, err
	}
	db := sql.OpenDB(c)
	return db, c, nil

}

func (s *Storage) InitDB() error {
	s.Filename, s.Path = ConstructDBFilenameAndPath(s.AppId, s.YYYYMMDD())
	// Don't re-initialize a database
	if s.db != nil {
		return nil
	}

	dbPath := path.Join(s.Path...)
	c, err := getDuckDBConnector(dbPath, []string{`SET threads TO 20`})
	if err != nil {
		return err
	}
	db := sql.OpenDB(c)

	// We need the raw context connector for appenders.
	s.connector = c
	s.db = db

	// We do not PREPARE schema.
	s.Schema = NewEmbedSql("schema")
	s.Schema.Init(db)

	// Tables must exist in order to prepare statements.
	// Create the tables next.
	err = s.InitTables()
	if err != nil {
		return err
	}
	// We do PREPARE the SQL for endpoints.
	s.Endpoints = NewEmbedSql("endpoints")
	s.Endpoints.Init(db)
	s.Endpoints.Prepare()

	activeStorageConnections[s.AppId+s.YYYYMMDD()] = s

	// This forces the creation of an empty file.
	db.Close()
	c, err = getDuckDBConnector(dbPath, make([]string, 0))
	db = sql.OpenDB(c)
	s.db, s.connector, err = OpenDatabase(dbPath)
	if err != nil {
		panic("could not open the database")
	}

	return nil
}

func (s *Storage) ExecNoLock(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {

	switch kind {
	case Schema:
		res, err := s.Schema.Exec(name, make([]any, 0))
		return res, err
	case Endpoint:
		if _, ok := s.Endpoints.Statements[name]; ok {
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
		row = s.Endpoints.QueryRow(name, args)
	default:
		zap.L().Error("Query: unknown kind of stored SQL",
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
	s.db.Close()
}

func (s *Storage) Flush() {
	// This flushes any outstanding actions/transactions on the DuckDB.
	// Good to do before closing the file or doing any operations on the DB file itself.
	_, err := s.db.Exec("CHECKPOINT;")
	if err != nil {
		// Try once more, after trying to open the database.
		if DoesDBExist(s.Path) {
			// It exists. Lets try to open it. For some reason, we were closed.
			s.db, s.connector, err = OpenDatabase(path.Join(s.Path...))
			if err != nil {
				msg := "tried to reopen the database, could not"
				zap.L().Error(msg, zap.Error(err))
				panic(msg)
			}
			zap.L().Info("had to reopen the datbase",
				zap.String("app_id", s.AppId),
				zap.String("filename", s.Filename),
				zap.String("date", s.YYYYMMDD()))
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

func (s *Storage) GetAppender(table string) {
	if s.appender != nil {
		panic("only one appender can be open at a time.")
	}

	conn, err := s.connector.Connect(context.Background())
	if err != nil {
		zap.L().Error("couild not get raw connector",
			zap.Error(err))
		panic("could not get raw connector")
	}
	appender, err := duckdb.NewAppenderFromConn(conn, "", table)
	if err != nil {
		panic("could not build appender")
	}
	s.appender = appender
}

func (s *Storage) FlushAppender() {
	err := s.appender.Flush()
	if err != nil {
		zap.L().Error("could not flush appender", zap.Error(err))
	}
}

func (s *Storage) CloseAppender() {
	err := s.appender.Close()
	if err != nil {
		zap.L().Fatal("could not close appender", zap.Error(err))
	}
	s.appender = nil
	s.Flush()
}

func (s *Storage) AppendRow(row ...driver.Value) error {
	err := s.appender.AppendRow(row...)
	return err
}

func (s *Storage) GetEtlFromDb(name string) (EtlRow, error) {
	raw := s.QueryRow(Endpoint,
		"get_etl",
		EmbedParamMap{"name": name})

	// var name, kind, body, lastRun string
	//err := row.Scan(&name, &kind, &body, &lastRun)
	var etlRow EtlRow
	err := raw.Scan(&etlRow.Inserted, &etlRow.Name, &etlRow.Kind, &etlRow.Body)

	if err != nil {
		msg := "could not get ETL from DB"
		zap.L().Error(msg,
			zap.String("etl_name", name),
		)
		return EtlRow{}, fmt.Errorf("%s: %s", msg, err.Error())
	}
	return etlRow, nil
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
		theSql = etlRow.Body.String
	} else {
		theSql = s.Endpoints.Files[name]
	}

	// We now are going to figure out which named params are present in the SQL.
	// That way, we only create named args for things that are present.
	// The SQL engine does not like when you pass named paramters that do not exist in the SQL.
	// E.g. we cannot provide more names than exist.
	re := regexp.MustCompile(`\` + SQL_NAMED_PARAM_SYMBOL + `([a-zA-Z0-9_]+)`)
	matches := re.FindAllString(theSql, -1)

	zap.L().Debug("PrepareNamedArgs found named args in SQL",
		zap.Any("named_args", matches),
		zap.String("the_sql", theSql))

	// And, check everything we found in the SQL is in the params
	named := make([]any, 0)

	for _, arg := range matches {
		trimmed := strings.Replace(arg, "$", "", 1)
		zap.L().Debug("matching args to params", zap.String("arg", arg), zap.String("trimmed", trimmed))
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
	row := s.Endpoints.Statements[etl].QueryRow(args...)
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
