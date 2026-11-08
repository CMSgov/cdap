package endpoints

import (
	"errors"
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
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

	app := metabase.App{
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
	case "weekly":
		im, err = openWeeklyDB(c, app, body)
		if err != nil {
			return
		}
		defer im.Close()
	}

	_, err = metabase.Exec(im, metabase.EmbeddedEndpoints.GetOrPanic("summary_create"), metabase.EmbedParamMap{
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

func openDailyDB(c *gin.Context, app metabase.App, body SummaryPostBody) (metabase.IMetabase, error) {
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

func openWeeklyDB(c *gin.Context, app metabase.App, body SummaryPostBody) (metabase.IMetabase, error) {
	if body.WeekNumber < 1 || body.WeekNumber > 53 {
		msg := fmt.Sprintf("must provide valid week number (1-53), not %d", body.WeekNumber)
		BadRequest(c, errors.New(msg), msg)
		return nil, errors.New(msg)
	}

	currentYear := time.Now().Year()
	if body.YearNumber < 2000 || body.YearNumber > currentYear {
		msg := fmt.Sprintf("must provide valid year (2000-%d), not %d", currentYear, body.YearNumber)
		BadRequest(c, errors.New(msg), msg)
		return nil, errors.New(msg)
	}

	im, err := metabase.NewWeeklyDatabase(
		app,
		body.YearNumber,
		body.WeekNumber,
	)
	if err != nil {
		ServerError(c, err, "could not create daily database")
		return nil, err
	}
	err = im.Open(metabase.OpenExistingOnly)
	if err != nil {
		BadRequest(c, err, fmt.Sprintf("no weekly database exists %s", body.YYYYMMDD))
		return nil, err
	}

	return im, nil
}
