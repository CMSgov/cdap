package storage

import (
	"context"
	"database/sql"
	"sync"

	"github.com/navapbc/its-log/internal/types"
)

type StorageType int

const (
	LiveStorage StorageType = iota
	ArchiveStorage
	ConsolidatedStorage
)

type StorageConfig struct {
	AppId string
	Date  string
	Kind  StorageType
}
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
