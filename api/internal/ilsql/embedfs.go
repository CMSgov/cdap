package ilsql

import (
	"embed"
	"path"
)

//go:embed endpoints
var endpointFS embed.FS

//go:embed schema
var schemaFS embed.FS

func GetEndpointSql(filename string) string {
	sql, err := endpointFS.ReadFile(path.Join("endpoints", filename))
	if err != nil {
		panic(err)
	}
	return string(sql)
}

func GetEndpointFS() embed.FS {
	return endpointFS
}

func GetDBSchema() string {
	sql, err := schemaFS.ReadFile(path.Join("schema", "schema.sql"))
	if err != nil {
		panic(err)
	}
	return string(sql)
}
