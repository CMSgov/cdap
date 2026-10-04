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
	"slices"
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

// Helper for the endpoints and other uses across the codebase
// This is the preferred entrypoint to the Storage API.
func SetupDB(appId string, date string) (*Storage, error) {
	// Did we store it in the map?
	// If so, return it. We want these to be persistent for the session
	if s, ok := activeStorageConnections[appId+date]; ok {
		return s, nil
	}

	// Otherwise, set it up
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

	activeStorageConnections[appId+date] = s

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

func (s *Storage) InitDB() error {
	// Compute filename based on date and app ID
	s.Filename = fmt.Sprintf("%s_%s.duckdb", s.AppId, s.YYYYMMDD())
	s.Path = []string{viper.GetString("storage.path"), s.Filename}

	// Don't re-initialize a database
	if s.db != nil {
		return nil
	}

	dbPath := path.Join(path.Join(s.Path...))
	// Create tables
	// DEBUG LOG
	// log.Printf("Storage.Init: opening %s\n", s.Filename)
	c, err := duckdb.NewConnector(dbPath, func(execer driver.ExecerContext) error {
		// https://duckdb.org/docs/current/configuration/overview
		bootQueries := []string{
			`SET threads TO 1`,
			// `SET schema=main`,
			// `SET search_path=main`,
		}
		for _, query := range bootQueries {
			_, err := execer.ExecContext(context.Background(), query, nil)
			if err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return err
	}
	db := sql.OpenDB(c)

	// We might need the raw context connector for appenders.
	s.connector = c
	s.db = db

	s.Schema = NewEmbedSql("schema")
	s.Schema.Init(db)
	// We do not PREPARE schema.

	// Tables must exist in order to prepare statements.
	// Create the tables next.
	err = s.InitTables()
	if err != nil {
		return err
	}

	s.Endpoints = NewEmbedSql("endpoints")
	s.Endpoints.Init(db)
	s.Endpoints.Prepare()

	return nil
}

func (s *Storage) ExecNoLock(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {

	switch kind {
	case Schema:
		res, err := s.Schema.Exec(name, EmbedParamMap{})
		return res, err
	case Endpoint:
		if _, ok := s.Endpoints.Statements[name]; ok {
			args, err := s.PrepareNamedArgs(name, params)
			if err != nil {
				return nil, err
			}
			// Get the SQL
			theSql := s.Endpoints.Files[name]
			res, err := s.db.ExecContext(context.Background(), theSql, args...)
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
	s.Lock()
	res, err := s.ExecNoLock(kind, name, params)
	s.Unlock()
	return res, err
}

func (s *Storage) Query(kind StoredSql, name string, params EmbedParamMap) (*sql.Rows, error) {
	var err error
	var res *sql.Rows

	err = errors.New("unknown kind of stored SQL")

	s.Lock()
	switch kind {
	case Schema:
		zap.L().Error("cannot query a schema")
	case Endpoint:
		res, err = s.Endpoints.Query(name, params)
	default:
		zap.L().Error("Query: unknown kind of stored SQL",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
	}
	s.Unlock()

	return res, err
}

func (s *Storage) QueryRow(kind StoredSql, name string, params EmbedParamMap) *sql.Row {
	var row *sql.Row
	s.Lock()
	switch kind {
	case Endpoint:
		row = s.Endpoints.QueryRow(name, params)
	default:
		zap.L().Error("Query: unknown kind of stored SQL",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
	}
	s.Unlock()

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

func (s *Storage) GetDB() *sql.DB {
	return s.db
}

func (s *Storage) Lock() {
	// log.Println("locking")
	s.lock.Lock()
}

func (s *Storage) Unlock() {
	// log.Println("unlocking")
	s.lock.Unlock()
}

func (s *Storage) Delete() {
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
}

func (s *Storage) AppendRow(row ...driver.Value) error {
	err := s.appender.AppendRow(row...)
	return err
}

// Consumes the name of embedded SQL and a parameter map.
// Finds the named params in the SQL (which must begin with $_)
// and looks up the name in the map, returning a list of sql.NamedArgs
// matching the variables needed to execute the SQL
func (s *Storage) PrepareNamedArgs(name string, params EmbedParamMap) ([]any, error) {
	// Look for the named params expected in the SQL
	if _, ok := s.Endpoints.Files[name]; !ok {
		return nil, fmt.Errorf("could not prepare args for %s; not found", name)
	}
	theSql := s.Endpoints.Files[name]
	re := regexp.MustCompile(`\` + SQL_NAMED_PARAM_SYMBOL + `(_[a-zA-Z0-9_]+)`)
	matches := re.FindAllString(theSql, -1)
	zap.L().Debug("found named args in SQL",
		zap.Any("named_args", matches))

	// Check all of the params are in the args we found
	for key := range params {
		zap.L().Debug("matching params to expected args",
			zap.String("param", key),
			zap.Any("matches", matches))
		if !slices.Contains(matches, fmt.Sprintf("%s_%s", SQL_NAMED_PARAM_SYMBOL, key)) {
			return nil, fmt.Errorf("%s not found in SQL named arg list", key)
		}
	}
	// And, check everything we found in the SQL is in the params
	for _, arg := range matches {
		trimmed := strings.Replace(arg, "$_", "", 1)
		zap.L().Debug("matching args to params", zap.String("arg", arg), zap.String("trimmed", trimmed))
		if _, ok := params[trimmed]; !ok {
			return nil, fmt.Errorf("%s found in SQL but not in params", trimmed)
		}
	}

	// At this point, we should be good to go.
	named := make([]any, 0)
	for arg, val := range params {
		named = append(named, sql.Named(arg, val))
	}
	return named, nil
}
