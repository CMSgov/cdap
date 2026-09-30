package storage

import (
	"context"
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
	Statements map[string]*sql.Stmt
	db         *sql.DB
}

type EmbedParamMap map[string]any

func NewEmbedSql(path string) *EmbedSql {
	esql := &EmbedSql{}
	esql.Path = path
	esql.Files = make(map[string]string, 0)
	esql.Statements = make(map[string]*sql.Stmt, 0)

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

// https://go.dev/doc/database/prepared-statements#behavior
func (e *EmbedSql) Prepare() {
	for name, contents := range e.Files {
		// Prepare everything into the DB if it has not happened before.
		if _, ok := e.Statements[name]; !ok {
			stmt, err := e.db.Prepare(contents)
			if err != nil {
				zap.L().Fatal("cannot prepare embedded SQL statement",
					zap.String("path", e.Path),
					zap.String("name", name),
					zap.String("contents", contents),
					zap.Error(err))
			}
			zap.L().Debug("prepared statement", zap.String("name", name))
			e.Statements[name] = stmt
			_, err = stmt.Exec()
			if err != nil {
				zap.L().Fatal("could not prepare statement",
					zap.String("name", name))
			}
		}
	}
}

func (e *EmbedSql) Exec(name string, params EmbedParamMap) (sql.Result, error) {

	prepped := make([]sql.NamedArg, 0)
	for name, val := range params {
		prepped = append(prepped, sql.Named(name, val))
	}

	var res sql.Result = nil
	var err error

	if stmt, ok := e.Statements[name]; ok {
		res, err = stmt.ExecContext(context.Background(), prepped)
	} else {
		res, err = e.db.ExecContext(context.Background(), e.Files[name], prepped)
	}

	return res, err
}

func (e *EmbedSql) Query(name string, params EmbedParamMap) (*sql.Rows, error) {

	prepped := make([]sql.NamedArg, 0)
	for name, val := range params {
		prepped = append(prepped, sql.Named(name, val))
	}

	return e.Statements[name].QueryContext(context.Background(), prepped)
}
