package endpoints

import (
	"errors"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/consolidate"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/metabase"
)

type ConsolidateBody struct {
	Kind     string `json:"kind" validate:"required,oneof=daily monthly full"`
	YYYYMMDD string `json:"ymd" validate:"omitempty,yyyymmdd"`
	Year     int    `json:"year" validate:"omitempty,gte=2000"`
	Month    int    `json:"month" validate:"omitempty,gte=1,lte=12"`
}

// Archives from all instances today into a DailyDatabase
func Consolidate(c *gin.Context) {
	var body ConsolidateBody
	var err error
	if err = c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}

	// FIXME: this could be at the Gin framework level.
	validate := setupValidators()
	if err := validate.Struct(body); err != nil {
		BadRequest(c, err, "json does not validate")
		return
	}

	app := metabase.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	err = nil
	switch body.Kind {
	case "daily":
		if len(body.YYYYMMDD) < 10 {
			BadRequest(c, errors.New("must provide YYYY-MM-DD"), "must provide ymd")
			return
		}
		err = consolidate.Consolidate(&consolidate.DailyParams{
			App:      app,
			YYYYMMDD: body.YYYYMMDD,
		})
	case "monthly":
		if body.Month == 0 || body.Year == 0 {
			BadRequest(c, errors.New("must provide month number and year"), "missing month or year")
			return
		}
		err = consolidate.Consolidate(&consolidate.MonthlyParams{
			App:         app,
			MonthNumber: body.Month,
			YearNumber:  body.Year,
		})
	case "yearly":
		if body.Year == 0 {
			BadRequest(c, errors.New("must provide year"), "missing year")
			return
		}
		err = consolidate.Consolidate(&consolidate.YearlyParams{
			App:        app,
			YearNumber: body.Year,
		})
	case "full":
		err = consolidate.Consolidate(&consolidate.FullParams{
			App: app,
		})
	default:
		// Should not get here with validator
		BadRequest(c, errors.New("never this"), "cannot consolidate")
		return
	}
	if err != nil {
		ServerError(c, err, "could not create archive")
		return
	}

	StatusOk(c, "archive created")
}
