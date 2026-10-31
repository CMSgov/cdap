package storage

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"os"
	"path"

	"github.com/spf13/viper"
	"go.uber.org/zap"
)

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
	// Give it the old college try...
	if s.lock.TryLock() {
		// This means the lock was acquired...
		defer s.lock.Unlock()
	} else {
		// It is locked. Unlock it.
		defer s.lock.Unlock()
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
