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
	Table      string `json:"table" validate:"required,oneof=event summary"`
	Kind       string `json:"kind" validate:"required,oneof=daily weekly monthly all"`
	YYYYMMDD   string `json:"ymd" validate:"omitempty,yyyymmdd"`
	WeekNumber int    `json:"week" validate:"omitempty,gte=1,lte=53"`
	Year       int    `json:"year" validate:"omitempty,gte=2000"`
	Month      int    `json:"month" validate:"omitempty,gte=1,lte=12"`
}

// Archives from all instances today into a DailyDatabase
func Consolidate(c *gin.Context) {
	var body ConsolidateBody
	var err error
	if err = c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}

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
	var tableKind consolidate.ConsolidationKind
	switch body.Table {
	case "event":
		tableKind = consolidate.EventsConsolidation
	case "summary":
		tableKind = consolidate.SummaryConsolidation
	default:
		tableKind = consolidate.EventsConsolidation
	}

	switch body.Kind {
	case "daily":
		if len(body.YYYYMMDD) < 10 {
			BadRequest(c, errors.New("must provide YYYY-MM-DD"), "must provide ymd")
			return
		}
		err = consolidate.Consolidate(&consolidate.DailyParams{
			Kind:     tableKind,
			App:      app,
			YYYYMMDD: body.YYYYMMDD,
		})
	case "weekly":
		if body.WeekNumber == 0 || body.Year == 0 {
			BadRequest(c, errors.New("must provide week number and year"), "missing week or year")
			return
		}
		err = consolidate.Consolidate(&consolidate.WeeklyParams{
			Kind:       tableKind,
			WeekNumber: body.WeekNumber,
			YearNumber: body.Year,
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
