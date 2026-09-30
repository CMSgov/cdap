package storage

import (
	"database/sql"
	"sync"

	"github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/types"
)

type Storage struct {
	AppId     string
	Path      []string
	ILTime    *types.ILTime
	Filename  string
	firstUse  bool
	lock      sync.Mutex
	db        *sql.DB
	connector *duckdb.Connector
	appender  *duckdb.Appender
	Schema    *EmbedSql
	Endpoints *EmbedSql
}

type StorageMap map[string]*Storage
