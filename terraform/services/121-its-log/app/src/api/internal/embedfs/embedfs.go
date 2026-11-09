package embedfs

import (
	"embed"
	"fmt"
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
}

type EmbedParamMap map[string]any

var EmbeddedSchema = NewEmbedSql("schema")
var EmbeddedEndpoints = NewEmbedSql("endpoints")

func NewEmbedSql(path string) *EmbedSql {
	esql := &EmbedSql{}
	esql.Path = path
	esql.Files = make(map[string]string, 0)
	esql.Init()

	return esql
}

func (e *EmbedSql) Init() {
	switch e.Path {
	case "endpoints":
		e.filesystem = endpointFS
	case "schema":
		e.filesystem = schemaFS
	default:
		zap.L().Fatal("unknown embedded filesystem; cannot init",
			zap.String("path", e.Path))
	}
	e.ReadContents()
}

func (e *EmbedSql) Contains(name string) bool {
	_, exists := e.Files[name]
	return exists
}

func (e *EmbedSql) Get(name string) (string, error) {
	if e.Contains(name) {
		return e.Files[name], nil
	} else {
		return "", fmt.Errorf("cannot find embedded sql for %s", name)
	}
}

func (e *EmbedSql) GetOrPanic(name string) string {
	if e.Contains(name) {
		return e.Files[name]
	} else {
		panic(fmt.Sprintf("cannot find embedded sql for %s", name))
	}
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
