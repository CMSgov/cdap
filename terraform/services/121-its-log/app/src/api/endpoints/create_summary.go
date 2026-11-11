package endpoints

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
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
	cp, err := getSummaryParams(app, body.Kind, body.YYYYMMDD, body.Year, body.Month)
	if err != nil {
		BadRequest(c, err, "bad summary params")
	}
	var destination *metabase.Metabase
	switch cp := cp.(type) {
	case *metabase.DailyParams:
		// We are consolidating instances into a daily DB.
		destination, err = metabase.NewDailyDatabase(&metabase.DailyParams{
			App:      cp.App,
			YYYYMMDD: cp.YYYYMMDD,
		})
	case *metabase.MonthlyParams:
		destination, err = metabase.NewMonthlyDatabase(&metabase.MonthlyParams{
			App:         cp.App,
			YearNumber:  cp.YearNumber,
			MonthNumber: cp.MonthNumber,
		})
	case *metabase.YearlyParams:
		destination, err = metabase.NewYearlyDatabase(&metabase.YearlyParams{
			App:        cp.App,
			YearNumber: cp.YearNumber,
		})
	case *metabase.FullParams:
		destination, err = metabase.NewFullDatabase(&metabase.FullParams{
			App: cp.App,
		})
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
	defer func() {
		destination.Flush()
		destination.Close()
	}()

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

func getSummaryParams(app types.App, kind string, ymd string, year int, month int) (metabase.MetaParams, error) {
	switch kind {
	case "daily":
		return &metabase.DailyParams{
			App:      app,
			YYYYMMDD: ymd,
		}, nil
	case "monthly":
		return &metabase.MonthlyParams{
			App:         app,
			MonthNumber: month,
		}, nil
	case "yearly":
		return &metabase.YearlyParams{
			App:        app,
			YearNumber: year,
		}, nil
	case "full":
		return &metabase.FullParams{
			App: app,
		}, nil
	default:
		return nil, errors.New("could not setup summary database")
	}
}

func getSummaryDB(app types.App, kind string, ymd string, year int, month int) (*metabase.Metabase, error) {
	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	var err error
	cp, err := getSummaryParams(app, kind, ymd, year, month)
	if err != nil {
		return nil, err
	}
	var destination *metabase.Metabase
	switch cp := cp.(type) {
	case *metabase.DailyParams:
		// We are consolidating instances into a daily DB.
		destination, err = metabase.NewDailyDatabase(&metabase.DailyParams{
			App:      cp.App,
			YYYYMMDD: cp.YYYYMMDD,
		})
	case *metabase.MonthlyParams:
		destination, err = metabase.NewMonthlyDatabase(&metabase.MonthlyParams{
			App:         cp.App,
			YearNumber:  cp.YearNumber,
			MonthNumber: cp.MonthNumber,
		})
	case *metabase.YearlyParams:
		destination, err = metabase.NewYearlyDatabase(&metabase.YearlyParams{
			App:        cp.App,
			YearNumber: cp.YearNumber,
		})
	case *metabase.FullParams:
		destination, err = metabase.NewFullDatabase(&metabase.FullParams{
			App: cp.App,
		})
	default:
		return nil, errors.New("cannot consolidation unknown type")
	}
	if err != nil {
		return nil, err
	}

	// Open the database we created.
	err = destination.Open(metabase.ReplaceExistingOrCreateNew)
	if err != nil {
		return nil, err
	}
	return destination, err

}
