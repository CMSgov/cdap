package storage

import (
	"context"
	"database/sql"
	"sync"

	"github.com/navapbc/its-log/internal/types"
)

type StorageConfig struct {
	AppId string
	Date  string
	Kind  StorageType
}
type Storage struct {
	AppId     string
	KeyId     string
	Path      []string
	ILTime    *types.ILTime
	Filename  string
	Kind      StorageType
	firstUse  bool
	lock      sync.Mutex
	Context   context.Context
	db        *sql.DB
	Schema    *EmbedSql
	Endpoints *EmbedSql
}

type StorageMap map[string]*Storage
