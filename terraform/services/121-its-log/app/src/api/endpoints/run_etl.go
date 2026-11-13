package endpoints

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// This is the handler if we call it directly from the API.
// We only get the gin context.
func RunEtl(c *gin.Context) {
	var body etl.RunEtlBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "invalid json")
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

	// We now have some choices.
	// We could be running an SQL or a Starlark ETL, and
	// we would be storing it to either the summary table in the DB
	// or to a CSV in the `export` pathway.

	switch body.Destination {
	case "summary":
		inserted, err := etl.RunAndInsertEtl(app, destination, body)
		if err != nil {
			ServerError(c, err, "could not run and insert etl")
			return
		}
		zap.L().Info("summaries inserted", zap.Int("rows", inserted))
	case "csv":
		// pass
	}
	StatusOk(c, "etl ran")

	// etlP := &etl.RunEtlParams{
	// 	AppId:   appId,
	// 	KeyId:   keyId,
	// 	GinCtx:  c,
	// 	Storage: s,
	// 	EtlName: name,
	// 	Payload: payload,
	// }

	// etlErr := runEtl(etlP)

	// if etlErr == nil {
	// 	etl.NewStandardOkResponse(c, etlP).SetStatus(http.StatusOK).Send()
	// } else {
	// 	ser := etl.NewStandardErrorResponse(etlP, etlErr)
	// 	ser.SetStatus(http.StatusInternalServerError).Send("golang ETL error")
	// }
}

// func runEtl(etlP *etl.RunEtlParams) error {
// 	etlRow, err := etlP.Storage.GetEtlFromDb(etlP.EtlName)
// 	if err != nil {
// 		return err
// 	}

// 	etlP, err = insertDefaultParams(etlP)
// 	if err != nil {
// 		return err
// 	}

// 	switch etlRow.Kind {
// 	case constants.SQL:
// 		err := etlRunSql(etlP, etlRow)
// 		if err != nil {
// 			return err
// 		}
// 	case constants.GOLANG:
// 		err := etlRunGolang(etlP, etlRow, nil)
// 		if err != nil {
// 			return err
// 		}
// 	case constants.STARLARK:
// 		err := etlRunStarlark(etlP, etlRow, nil)
// 		if err != nil {
// 			return err
// 		}

// 	case constants.SEQUENCE:
// 		// The name of the step will have been loaded into the context.

// 	default:
// 		msg := "unknown kind of etl: " + etlRow.Kind
// 		log.Println(msg)
// 		if etlP.GinCtx != nil {
// 			ser := etl.NewStandardErrorResponse(etlP, nil)
// 			ser.SetStatus(http.StatusBadRequest).Send(msg)
// 		}
// 		return fmt.Errorf("%s: %s", msg, http.StatusText(http.StatusInternalServerError))
// 	}

// 	_, err = etlP.Storage.Exec(storage.Endpoint, "update_last_run", storage.EmbedParamMap{
// 		"key_id":   etlP.KeyId,
// 		"etl_name": etlP.EtlName,
// 		"activity": "run etl via API",
// 	})

// 	if err != nil {
// 		msg := "could not update ETL metadata"
// 		log.Println(msg)
// 		if etlP.GinCtx != nil {
// 			ser := etl.NewStandardErrorResponse(etlP, nil)
// 			ser.SetStatus(http.StatusInternalServerError).Send(msg)
// 		}
// 		return fmt.Errorf("%s: %s", msg, err.Error())
// 	}

// 	return nil
// }

// func InsertSummaryRows(source string, etlP *etl.RunEtlParams, summaries []etl.ItslogSummary) error {
// 	//
// 	// Now, write the new summar(y|ies) to the summary table.
// 	for _, summary := range summaries {
// 		var deleted bool = false

// 		etlP.Payload["key_id"] = etlP.KeyId
// 		// What date should this be?
// 		etlP.Payload["date"] = etlP.Storage.YYYYMMDD()
// 		etlP.Payload["operation"] = summary.Operation
// 		etlP.Payload["tags"] = summary.Tags
// 		etlP.Payload["data"] = summary.Data

// 		if !deleted && etlP.DeleteBeforeInsert {
// 			zap.L().Debug("deleting existing summaries", zap.String("etl", etlP.EtlName))
// 			// Delete existing rows that match the key_id/date/operation
// 			delArgs, err := etlP.Storage.PrepareNamedArgs("delete_existing_summaries", etlP.Payload)
// 			if err != nil {
// 				return err
// 			}
// 			_, err = etlP.Storage.Endpoints.Exec("delete_existing_summaries", delArgs)
// 			if err != nil {
// 				zap.L().Error("possible error delete_existing_summaries",
// 					zap.String("source", source),
// 					zap.Any("payload", etlP.Payload),
// 					zap.Error(err))
// 			}
// 			deleted = true
// 		}

// 		args, err := etlP.Storage.PrepareNamedArgs("insert_full_summary", etlP.Payload)
// 		if err != nil {
// 			return err
// 		}

// 		etlP.Storage.Lock("InsertSummaryRows")
// 		_, err = etlP.Storage.Endpoints.Exec("insert_full_summary", args)
// 		if err != nil {
// 			zap.L().Error("insertsummaryrows:insert_full_summary",
// 				zap.String("source", source),
// 				zap.Any("payload", etlP.Payload),
// 				zap.Error(err))
// 			etlP.Storage.Unlock("InsertSummaryRows")
// 			return err
// 		}
// 		etlP.Storage.Unlock("InsertSummaryRows")
// 	}

// 	return nil
// }
