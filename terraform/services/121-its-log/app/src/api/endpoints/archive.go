package endpoints

import (
	"database/sql"
	"fmt"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
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

	duck, err := sql.Open("duckdb", ":memory:")
	if err != nil {
		ServerError(c, err, "could not open in-memory database")
		return
	}
	// "\n\t\tSELECT *\n\t\tFROM read_duckdb(\"/Users/jadudm/.its-log/data/pupper-instance-*-2026-11-07.duckdb\", table_name=\"events\")"
	q := fmt.Sprintf(`SELECT * FROM read_duckdb("%s/%s_instance_*_%s.%s", table_name="events")`,
		viper.GetString("storage.path"),
		app.AppId,
		body.YYYYMMDD,
		metabase.DUCKDB_EXTENSION,
	)
	rows, err := duck.Query(q)
	if err != nil {
		ServerError(c, err, "could not query databases for given app and date")
	}
	if rows.Err() != nil {
		ServerError(c, err, "rows error for app and date")
		return
	}

	id, err := metabase.NewDailyDatabase(app, body.YYYYMMDD)
	if err != nil {
		ServerError(c, err, "could not create archive")
		return
	}
	// Overwrite if it exists
	err = id.Open(metabase.ReplaceExistingOrCreateNew)
	if err != nil {
		ServerError(c, err, "could not open new archive")
		return
	}
	defer rows.Close()

	id.Lock("Archive")
	defer id.Unlock("Archive")
	defer id.Close()

	insert := "INSERT INTO events (key_id, cluster, tags, data) VALUES ($key_id, $cluster, $tags, $data)"
	for rows.Next() {
		var er metabase.EventsRow
		if err := rows.Scan(&er.Id, &er.Inserted, &er.KeyId, &er.Cluster, &er.Tags, &er.Data); err != nil {
			ServerError(c, err, "could not scan row")
			return
		}

		prepped, err := metabase.PrepareNamedArgs(insert, metabase.EmbedParamMap{
			"key_id":  er.KeyId,
			"cluster": er.Cluster,
			"tags":    er.Tags,
			"data":    er.Data,
		})
		if err != nil {
			ServerError(c, err, "could not prepare event insertion")
			return
		}
		_, err = id.GetDB().Exec(insert, prepped...)
		if err != nil {
			ServerError(c, err, "could not insert event")
			return
		}
	}

	StatusOk(c, "archive created")
}
