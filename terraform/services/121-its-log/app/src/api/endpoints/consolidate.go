package endpoints

import (
	"errors"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/consolidate"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/constants"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/gin-gonic/gin"
)

type ConsolidateBody struct {
	Kind     string `json:"kind" binding:"required,oneof=daily monthly full"`
	YYYYMMDD string `json:"ymd" binding:"omitempty,validateYMD"`
	Year     int    `json:"year" binding:"omitempty,gte=2000"`
	Month    int    `json:"month" binding:"omitempty,gte=1,lte=12"`
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
	// validate := setupValidators()
	// if err := validate.Struct(body); err != nil {
	// 	BadRequest(c, err, "json does not validate")
	// 	return
	// }

	app := types.App{
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
		err = consolidate.Consolidate(&metabase.DailyParams{
			App:      app,
			YYYYMMDD: body.YYYYMMDD,
		})
	case "monthly":
		if body.Month == 0 || body.Year == 0 {
			BadRequest(c, errors.New("must provide month number and year"), "missing month or year")
			return
		}
		err = consolidate.Consolidate(&metabase.MonthlyParams{
			App:         app,
			MonthNumber: body.Month,
			YearNumber:  body.Year,
		})
	case "yearly":
		if body.Year == 0 {
			BadRequest(c, errors.New("must provide year"), "missing year")
			return
		}
		err = consolidate.Consolidate(&metabase.YearlyParams{
			App:        app,
			YearNumber: body.Year,
		})
	case "full":
		err = consolidate.Consolidate(&metabase.FullParams{
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
