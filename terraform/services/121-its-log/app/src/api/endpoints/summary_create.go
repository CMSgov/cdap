package endpoints

import (
	"errors"
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
)

type SummaryPostBody struct {
	Operation   string   `json:"operation" binding:"required"`
	Tags        []string `json:"tags"`
	Data        any      `json:"data" binding:"required"`
	Kind        string   `json:"kind" binding:"required"`
	YYYYMMDD    string   `json:"ymd"`
	WeekNumber  int      `json:"week"`
	MonthNumber int      `json:"month"`
	YearNumber  int      `json:"year"`
}

func SummaryCreate(c *gin.Context) {

	var body SummaryPostBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}

	// Summaries are either daily, weekly, yearly, or consolidated
	// body.Kind = base.GetParamOrPanic(c, "kind", SUMMARY_ALLOWED_KINDS)

	app := types.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	var im metabase.IMetabase
	var err error
	switch body.Kind {
	case "daily":
		im, err = openDailyDB(c, app, body)
		if err != nil {
			return
		}
		defer im.Close()
	default:
		ServerError(c, errors.New("unknown summary target"), "unknown summary target")
		return
	}

	_, err = metabase.Exec(im, embedfs.EmbeddedEndpoints.GetOrPanic("summary_create"), embedfs.EmbedParamMap{
		"key_id":    app.KeyId,
		"operation": body.Operation,
		"tags":      body.Tags,
		"data":      body.Data,
	})
	if err != nil {
		ServerError(c, err, "could not insert summary")
		return
	}

	StatusOk(c, "summary created")
}

func openDailyDB(c *gin.Context, app types.App, body SummaryPostBody) (metabase.IMetabase, error) {
	err := types.IsValidYYYYMMDD(body.YYYYMMDD)
	if err != nil {
		BadRequest(c, err, "invalid YYYY-MM-DD")
		return nil, err
	}
	im, err := metabase.NewDailyDatabase(
		app,
		body.YYYYMMDD,
	)
	if err != nil {
		ServerError(c, err, "could not create daily database")
		return nil, err
	}
	err = im.Open(metabase.OpenExistingOnly)
	if err != nil {
		BadRequest(c, err, fmt.Sprintf("no daily database exists %s", body.YYYYMMDD))
		return nil, err
	}

	return im, nil
}
