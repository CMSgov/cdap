package storage

import (
	"database/sql"
	"embed"
	"io/fs"
	"path"
	"strings"

	"go.uber.org/zap"
)

//go:embed endpoints
var endpointFS embed.FS

//go:embed schema
var schemaFS embed.FS

type EmbedSql struct {
	Path       string
	filesystem embed.FS
	Files      map[string]string
	db         *sql.DB
}

type EmbedParamMap map[string]any

func NewEmbedSql(path string) *EmbedSql {
	esql := &EmbedSql{}
	esql.Path = path
	esql.Files = make(map[string]string, 0)

	return esql
}

func (e *EmbedSql) Init(db *sql.DB) {
	switch e.Path {
	case "endpoints":
		e.filesystem = endpointFS
	case "schema":
		e.filesystem = schemaFS
	default:
		zap.L().Fatal("unknown embedded filesystem; cannot init",
			zap.String("path", e.Path))
	}

	e.db = db
	e.ReadContents()
}

func (e *EmbedSql) ReadContents() {

	dirEntries, err := fs.ReadDir(e.filesystem, e.Path)
	if err != nil {
		panic("cannot read directory of embedded filesystem")
	}

	for _, entry := range dirEntries {
		if strings.HasSuffix(entry.Name(), "sql") {
			contents, err := e.filesystem.ReadFile(path.Join(e.Path, entry.Name()))
			if err != nil {
				zap.L().Fatal("cannot read embedded file",
					zap.String("path", e.Path),
					zap.String("entry", entry.Name()))
			}
			nameWithoutExt := strings.TrimSuffix(entry.Name(), ".sql")
			e.Files[nameWithoutExt] = string(contents)
		}
	}
}

func (e *EmbedSql) Exec(name string, args []any) (sql.Result, error) {
	var res sql.Result = nil
	var err error

	res, err = e.db.Exec(e.Files[name], args...)
	if err != nil {
		zap.L().Error("EmbedSql Exec error",
			zap.String("name", name),
			zap.Any("args", args),
			zap.Error(err))
	}
	return res, err
}

func (e *EmbedSql) Query(name string, namedArgs []any) (*sql.Rows, error) {
	rows, err := e.db.Query(e.Files[name], namedArgs...)
	if err != nil {
		zap.L().Error("EmbedSql Exec else",
			zap.String("name", name),
			zap.Any("args", namedArgs),
			zap.Error(err))
	}
	return rows, nil
}

func (e *EmbedSql) QueryRow(name string, namedArgs []any) *sql.Row {
	stmt, err := e.db.Prepare(e.Files[name])
	if err != nil {
		zap.L().Info("could not prepare etl", zap.String("name", name))
		return nil
	}
	row := stmt.QueryRow(namedArgs...)
	// row := e.db.QueryRow(e.Files[name], namedArgs)
	return row
}
