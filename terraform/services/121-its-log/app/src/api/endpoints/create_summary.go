package endpoints

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/consolidate"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
)

type SummaryPostBody struct {
	Operation string   `json:"operation" binding:"required"`
	Tags      []string `json:"tags"`
	Data      any      `json:"data" binding:"required"`
	Kind      string   `json:"kind" validate:"required,oneof=daily monthly yearly full"`
	YYYYMMDD  string   `json:"ymd" validate:"omitempty,yyyymmdd"`
	Year      int      `json:"year" validate:"omitempty,gte=2000"`
	Month     int      `json:"month" validate:"omitempty,gte=1,lte=12"`
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

	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	var err error
	cp, err := getParams(app, body)
	if err != nil {
		BadRequest(c, err, "bad summary params")
	}
	var destination metabase.IMetabase
	switch cp := cp.(type) {
	case *consolidate.DailyParams:
		// We are consolidating instances into a daily DB.
		destination, err = metabase.NewDailyDatabase(cp.App, cp.YYYYMMDD)
	case *consolidate.MonthlyParams:
		destination, err = metabase.NewMonthlyDatabase(cp.App, cp.YearNumber, cp.MonthNumber)
	case *consolidate.YearlyParams:
		destination, err = metabase.NewYearlyDatabase(cp.App, cp.YearNumber)
	case *consolidate.FullParams:
		destination, err = metabase.NewFullDatabase(cp.App)
	default:
		BadRequest(c, errors.New("cannot consolidation unknown type"), "unknown consolidation")
	}
	if err != nil {
		ServerError(c, err, "cannot get summary database")
	}

	// Open the database we created.
	err = destination.Open(metabase.ReplaceExistingOrCreateNew)
	if err != nil {
		ServerError(c, errors.New("could not open summary databse"), "cannot open summary db")
	}
	defer destination.Close()

	_, err = metabase.Exec(destination, embedfs.EmbeddedEndpoints.GetOrPanic("summary_create"), embedfs.EmbedParamMap{
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

func getParams(app types.App, body SummaryPostBody) (consolidate.ConsolidationParams, error) {
	switch body.Kind {
	case "daily":
		return &consolidate.DailyParams{
			App:      app,
			YYYYMMDD: body.YYYYMMDD,
		}, nil
	case "monthly":
		return &consolidate.MonthlyParams{
			App:         app,
			MonthNumber: body.Month,
		}, nil
	case "yearly":
		return &consolidate.YearlyParams{
			App:        app,
			YearNumber: body.Year,
		}, nil
	case "full":
		return &consolidate.FullParams{
			App: app,
		}, nil
	default:
		return nil, errors.New("could not setup summary database")
	}
}
