package endpoints

import (
	"errors"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/constants"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/embedfs"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/gin-gonic/gin"
)

type SummaryPostBody struct {
	Kind      string   `json:"kind" binding:"required,oneof=daily monthly yearly full"`
	Operation string   `json:"operation" binding:"required"`
	Language  string   `json:"language" binding:"required,oneof=sql starlark"`
	Tags      []string `json:"tags"`
	Data      any      `json:"data" binding:"required"`
	YMD       string   `json:"ymd" binding:"omitempty"`
	Year      int      `json:"year" binding:"omitempty,gte=2000"`
	Month     int      `json:"month" binding:"omitempty,gte=1,lte=12"`
}

func SummaryCreate(c *gin.Context) {

	var body SummaryPostBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}

	app := types.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	sdbsp, err := getSummaryDbSetupParams(app, body.Kind, body.YMD, body.Year, body.Month)
	if err != nil {
		BadRequest(c, err, "could not set up database")
		return
	}
	destination, err := getSummaryDB(sdbsp)
	if err != nil {
		BadRequest(c, err, "cannot open database")
		return
	}
	// Open the database we created.
	err = destination.Open(metabase.OpenExistingOnly)
	if err != nil {
		ServerError(c, errors.New("could not open summary database"), "cannot open summary db")
		return
	}
	defer destination.Close()

	_, err = metabase.Exec(destination,
		embedfs.EmbeddedEndpoints.GetOrPanic("create_summary"),
		[]embedfs.EmbeddedParam{
			{Name: "key_id", Value: app.KeyId, Type: embedfs.EmbeddedString},
			{Name: "date", Value: body.YMD, Type: embedfs.EmbeddedString},
			{Name: "operation", Value: body.Operation, Type: embedfs.EmbeddedString},
			{Name: "tags", Value: body.Tags, Type: embedfs.EmbeddedJson},
			{Name: "data", Value: body.Data, Type: embedfs.EmbeddedJson},
		})
	if err != nil {
		ServerError(c, err, "could not insert summary")
		return
	}

	StatusCreated(c, "summary created")
}

func getSummaryDbSetupParams(app types.App, kind string, ymd string, year int, month int) (metabase.MetaParams, error) {
	switch kind {
	case "daily":
		if len(ymd) < len("2020-05-20") {
			return nil, errors.New("ymd is not yyyy-mm-dd for daily summary")
		}
		return &metabase.DailyParams{
			App:      app,
			YYYYMMDD: ymd,
		}, nil
	case "monthly":
		if (month < 0 || month > 12) || (year < 2000) {
			return nil, errors.New("invalid month or year for monthly summary")
		}
		return &metabase.MonthlyParams{
			App:         app,
			MonthNumber: month,
			YearNumber:  year,
		}, nil
	case "yearly":
		if year < 2000 {
			return nil, errors.New("invalid year for yearly summary")
		}
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

func getSummaryDB(cp metabase.MetaParams) (*metabase.Metabase, error) {
	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	var err error
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
		err = errors.New("cannot get summary db, unknown type")
	}
	if err != nil {
		return nil, err
	}

	return destination, err
}
