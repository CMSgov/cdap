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
	"strings"

	"github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type StoredSql int

const (
	Schema StoredSql = iota
	Endpoint
)

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

func BuildExecuteCall(name string, params EmbedParamMap) (string, error) {
	bound_params := make([]string, 0)
	for name, val := range params {
		switch v := val.(type) {
		case nil:
			// Don't include nil values?
			// bound_params = append(bound_params, fmt.Sprintf("%s := %v", name, val))
		case string:
			if v == "" {
				bound_params = append(bound_params, fmt.Sprintf("%s:=''", name))
			} else {
				bound_params = append(bound_params, fmt.Sprintf("%s:='%v'", name, val))
			}
		default:
			bound_params = append(bound_params, fmt.Sprintf("%s:=%v", name, v))
		}
	}
	return fmt.Sprintf("EXECUTE %s(%s);", name, strings.Join(bound_params, ",")), nil
}

func (s *Storage) ExecNoLock(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {

	switch kind {
	case Schema:
		// FIXME: infinite recursion...
		res, err := s.Schema.Exec(name, EmbedParamMap{})
		return res, err
	case Endpoint:
		if _, ok := s.Endpoints.Statements[name]; ok {
			call, err := BuildExecuteCall(name, params)
			if err != nil {
				return nil, err
			}
			// FIXME WRONG
			res, err := s.db.ExecContext(context.Background(), call)
			if err != nil {
				zap.L().Debug("ExecContext failure", zap.String("call", call))
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
