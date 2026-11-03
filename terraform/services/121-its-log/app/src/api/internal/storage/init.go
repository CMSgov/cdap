package storage

import (
	"database/sql"
	"path"

	"github.com/navapbc/its-log/internal/constants"
	"go.uber.org/zap"
)

func (s *Storage) InitDB() error {
	if s.Kind == ConsolidatedStorage {
		s.Filename, s.Path = ConstructDBFilenameAndPath(s.AppId, constants.CONSOLIDATED)
	} else {
		s.Filename, s.Path = ConstructDBFilenameAndPath(s.AppId, s.YYYYMMDD())
	}
	zap.L().Debug("creating db file",
		zap.Any("kind", s.Kind),
		zap.String("filename", s.Filename),
		zap.Any("path", s.Path))

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

func (s *Storage) InitTables() error {
	// Create tables
	_, err := s.Exec(Schema, "schema", nil)
	if err != nil {
		return err
	}
	_, err = s.Exec(Schema, "metadata", nil)
	if err != nil {
		return err
	}

	return nil
}

func (s *Storage) GetDB() *sql.DB {
	return s.db
}

// We name things based on dates
// This is a trivial wrapper around the time
// struct to return it as YYYY-MM-DD
func (s *Storage) YYYYMMDD() string {
	return s.ILTime.AsYYYYMMDD()
}
