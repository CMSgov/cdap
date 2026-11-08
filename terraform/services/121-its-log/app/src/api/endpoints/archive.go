package endpoints

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"runtime"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type ArchiveBody struct {
	YYYYMMDD string `json:"ymd" binding:"required"`
}

// Archives from all instances today into a DailyDatabase
func Archive(c *gin.Context) {
	var body ArchiveBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}
	err := types.IsValidYYYYMMDD(body.YYYYMMDD)
	if err != nil {
		BadRequest(c, err, "not a YYYY-MM-DD")
		return
	}

	app := metabase.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	// Source database(s)
	sourceDBs, err := sql.Open("duckdb", ":memory:")
	if err != nil {
		ServerError(c, err, "could not open in-memory database")
		return
	}
	defer sourceDBs.Close()

	// Destination database
	// Overwrite if it exists
	dest, err := metabase.NewDailyDatabase(app, body.YYYYMMDD)
	if err != nil {
		ServerError(c, err, "could not create archive")
		return
	}
	err = dest.Open(metabase.ReplaceExistingOrCreateNew)
	if err != nil {
		ServerError(c, err, "could not open new archive")
		return
	}
	defer dest.Close()

	// copyArchiveRows handles sending messages back to the user.
	err = copyArchiveRowsDirect(c, app, body.YYYYMMDD, sourceDBs, dest)
	if err != nil {
		return
	}

	StatusOk(c, "archive created")
}

func copyArchiveRowsDirect(c *gin.Context, app metabase.App, ymd string, source *sql.DB, dest metabase.IMetabase) error {
	var err error

	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	startHeapMB := m.TotalAlloc / 1024 / 1024

	// The "source" DB is actually an in-memory database.
	startRAMQ := `SELECT sum(memory_usage_bytes) as mub from duckdb_memory();`
	startTmpQ := `SELECT sum(temporary_storage_bytes) as tsb from duckdb_memory();`
	var sram int64
	var stmp int64
	var eram int64
	var etmp int64
	err = source.QueryRow(startRAMQ).Scan(&sram)
	err = source.QueryRow(startTmpQ).Scan(&stmp)

	// Build a file glob for the instance databases in /data
	sourcesGlob := filepath.Join(viper.GetString("storage.path"), fmt.Sprintf("%s_instance_*_%s.%s",
		app.AppId,
		ymd,
		metabase.DUCKDB_EXTENSION))
	zap.L().Info("sources path", zap.String("path", sourcesGlob))

	// Attach the destination database to the in-memory database
	attachDestinationQ := fmt.Sprintf(`ATTACH '%s' AS destination`,
		dest.FullFilename())
	_, err = source.Exec(attachDestinationQ)
	if err != nil {
		ServerError(c, err, "could not attach archive destination")
		return err
	}

	// Now, it is attached.
	// This is a direct copy from the globbed events tables in all of the
	// instance databases into the destination daily/archive database.
	copyQ := fmt.Sprintf(
		`INSERT INTO destination.events (inserted, key_id, cluster, tags, data)
			SELECT 
   				inserted, key_id, cluster, tags, data 
   				FROM read_duckdb('%s', table_name="events") as 'source'`, sourcesGlob)
	_, err = source.Exec(copyQ)
	if err != nil {
		ServerError(c, err, "could not copy to archive")
		return err
	}

	endHeapMB := m.TotalAlloc / 1024 / 1024
	zap.L().Info("Go RAM",
		zap.Uint64("start", startHeapMB),
		zap.Uint64("end", endHeapMB),
		zap.Uint64("diff", endHeapMB-startHeapMB))

	err = source.QueryRow(startRAMQ).Scan(&eram)
	err = source.QueryRow(startTmpQ).Scan(&etmp)
	zap.L().Info("DuckDB RAM",
		zap.Int64("start", sram/1024/1024),
		zap.Int64("end", eram/1024/1024),
		zap.Int64("diff", (eram-sram)/1024/1024),
	)
	zap.L().Info("DuckDB temp",
		zap.Int64("start", stmp/1024/1024),
		zap.Int64("end", etmp/1024/1024),
		zap.Int64("diff", (etmp-stmp)/1024/1024),
	)
	return nil
}

// func copyArchiveRowsSimplest(c *gin.Context, app metabase.App, ymd string, source *sql.DB, dest metabase.IMetabase) error {
// 	path := filepath.Join(viper.GetString("storage.path"), fmt.Sprintf("%s_instance_*_%s.%s",
// 		app.AppId,
// 		ymd,
// 		metabase.DUCKDB_EXTENSION))

// 	q := fmt.Sprintf(`SELECT * FROM read_duckdb('%s', table_name="events")`, path)
// 	rows, err := source.Query(q)
// 	if err != nil {
// 		ServerError(c, err, "could not query databases for given app and date")
// 	}
// 	if rows.Err() != nil {
// 		ServerError(c, err, "rows error for app and date")
// 		return err
// 	}
// 	defer rows.Close()

// 	dest.Lock("Archive")
// 	defer dest.Unlock("Archive")

// 	// THIS IS THE LEAST EFFICIENT WAY TO DO THIS.
// 	// However, it is the way that uses the least RAM.
// 	//
// 	// Other approaches include:
// 	//
// 	// Reading in a buffer of rows, and then flushing that buffer using an appender
// 	// https://duckdb.org/docs/2.0/clients/c/appender
// 	//
// 	// We could mount both the source DB and destination DB, and do it entirely in the DuckDB engine
// 	// INSERT INTO dest.events (SELECT * FROM source.events)
// 	// This would work because DuckDB can ATTACH multiple datbases at the same time.
// 	// However, it is unclear/not yet tested in practice how much RAM each DuckDB instance takes up.
// 	// There should only be 2-3 (# of instances), so that might not be an issue.
// 	//
// 	// For now, we will leave the most direct solution: iterate over the rows in the source database, and
// 	// insert into the destination database.
// 	insert := `INSERT INTO events (key_id, cluster, tags, data) VALUES ($key_id, $cluster, $tags, $data)`
// 	for rows.Next() {
// 		var er metabase.EventsRow
// 		if err := rows.Scan(&er.Id, &er.Inserted, &er.KeyId, &er.Cluster, &er.Tags, &er.Data); err != nil {
// 			ServerError(c, err, "could not scan row")
// 			return err
// 		}

// 		prepped, err := metabase.PrepareNamedArgs(insert, metabase.EmbedParamMap{
// 			"key_id":  er.KeyId,
// 			"cluster": er.Cluster,
// 			"tags":    er.Tags,
// 			"data":    er.Data,
// 		})
// 		if err != nil {
// 			ServerError(c, err, "could not prepare event insertion")
// 			return err
// 		}
// 		_, err = dest.GetDB().Exec(insert, prepped...)
// 		if err != nil {
// 			ServerError(c, err, "could not insert event")
// 			return err
// 		}
// 	}
// 	return nil
// }
