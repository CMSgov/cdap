package endpoints

import (
	"errors"
	"fmt"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/constants"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/etl"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/types"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// This is the handler if we call it directly from the API.
// We only get the gin context.
func RunEtl(c *gin.Context) {
	var body etl.RunEtlBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, fmt.Sprintf("invalid json, given: %v", body))
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

	// We're going to need the YMD for inserting summaries.
	// If we're processing a daily db, the YMD is already provided.
	// If we're processing a monthly, yearly, or full, we're going to have
	// to use today's date for the YMD.
	switch body.Kind {
	case "daily":
		// Leave YMD alone
	default:
		body.YMD = types.NewYYYYMMDD().String()
	}
	body.App = app

	// We now have some choices.
	// We could be running an SQL or a Starlark ETL, and
	// we would be storing it to either the summary table in the DB
	// or to a CSV in the `export` pathway.

	switch body.Destination {
	case "summary":
		inserted, err := etl.RunAndInsertEtl(destination, body)
		if err != nil {
			ServerError(c, err, "could not run etl and insert summary rows")
			return
		}
		zap.L().Info("summaries inserted", zap.Int("rows", inserted))
	case "csv":
		// pass
	}
	StatusOk(c, "etl ran")
}

// def output_to_csv():
//   // do stuff
//   // build a list
//   csv_shaped_result = {
// 	"columns": ["a", "b"]
// 	"rows": [
// 		[3, 5],
// 		[8, 16]
// 	]
// 	return csv_shaped_result
//   }
