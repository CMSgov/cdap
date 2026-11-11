package endpoints

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

type CreateETLPostBody struct {
	Name string `json:"name" binding:"required"`
	// Run a B64 validator that also filters the SQL for
	// INSERT, DELETE, and UPDATE.
	B64      string `json:"b64" binding:"required,validateB64SQL"`
	Kind     string `json:"kind" binding:"required,oneof=daily monthly yearly full"`
	YYYYMMDD string `json:"ymd" binding:"omitempty,validateYMD"`
	Year     int    `json:"year" binding:"omitempty,gte=2000"`
	Month    int    `json:"month" binding:"omitempty,gte=1,lte=12"`
}

func CreateEtl(c *gin.Context) {

	var body CreateETLPostBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	// We need the AppId and KeyId, which the middleware attached
	app := types.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	// And, pad it. DuckDB is very particular about its Base64 values.
	etl := padToMod4(body.B64)
	mp, err := getSummaryParams(app, body.Kind, body.YYYYMMDD, body.Year, body.Month)
	if err != nil {
		BadRequest(c, err, "cannot set up database params")
		return
	}
	destination, err := getSummaryDB(mp)
	if err != nil {
		BadRequest(c, err, "cannot set up database")
		return
	}
	defer destination.Close()
	err = destination.Open(metabase.OpenExistingOnly)
	if err != nil {
		BadRequest(c, err, "cannot open database")
		return
	}

	// Run the code to insert the ETL into the database
	_, err = metabase.Exec(destination,
		embedfs.EmbeddedEndpoints.GetOrPanic("create_etl"),
		types.M{
			"key_id": app.KeyId,
			"name":   body.Name,
			// FIXME: "kind" here is meant to be sql or starlark
			"kind": body.Kind,
			"body": etl,
		})

	if err != nil {
		zap.L().Error("etl save error", zap.Error(err))
		ServerError(c, err, "could not save etl step")
		return
	}

	StatusOk(c, "etl created")
}

func padToMod4(toPad string) string {
	// DuckDB wants Base64 values padded to mod(len, 4).
	// We'll make sure the padding is right, even though the client
	// should do this work.
	etl := strings.ReplaceAll(toPad, "=", "")
	offset := len(etl) % 4
	if offset != 0 {
		for range 4 - offset {
			etl += "="
		}
	}
	return etl
}
