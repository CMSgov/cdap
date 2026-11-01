package storage

import (
	"context"
	"database/sql"
	"sync"

	"github.com/navapbc/its-log/internal/types"
)

type Storage struct {
	AppId     string
	Path      []string
	ILTime    *types.ILTime
	Filename  string
	firstUse  bool
	lock      sync.Mutex
	Context   context.Context
	db        *sql.DB
	Schema    *EmbedSql
	Endpoints *EmbedSql
}

type StorageMap map[string]*Storage

type EtlRow struct {
	Name string
	Kind string
	Body string
}
