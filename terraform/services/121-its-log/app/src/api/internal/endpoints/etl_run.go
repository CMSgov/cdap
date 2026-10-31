package endpoints

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"go.uber.org/zap"
)

func checkRunEtlBody(c *gin.Context) (map[string]any, error) {
	// ETL steps can have an arbitrary POST body
	// But, they might send nothing.
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		body = []byte("{}")
	}
	payload := make(map[string]any)
	jsonErr := json.Unmarshal(body, &payload)
	if jsonErr != nil {
		payload = make(map[string]any)
	}

	zap.L().Debug("payload", zap.Any("payload", payload))
	for _, k := range []string{"date", "name"} {
		if _, ok := payload[k]; !ok {
			return nil, fmt.Errorf("missing in body: %s", k)
		}
		switch t := payload[k].(type) {
		case string:
			// OK
		default:
			return nil, fmt.Errorf("expected a string for %s; received %T", k, t)
		}
	}
	return payload, nil
}

// This is the handler if we call it directly from the API.
// We only get the gin context.
func RunEtl(c *gin.Context) {
	appId := base.GetOrPanic(c, "AppId")
	keyId := base.GetOrPanic(c, "KeyId")

	payload, err := checkRunEtlBody(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": fmt.Sprintf("ETL run must have a name and date: %s", err.Error()),
			"date":    "?",
		})
		return
	}

	date := payload["date"].(string)
	name := payload["name"].(string)

	s, err := SetupGinDB(c, appId, date)
	if err != nil {
		return
	}
	defer s.Close()

	etlP := &etl.RunEtlParams{
		AppId:   appId,
		KeyId:   keyId,
		GinCtx:  c,
		Storage: s,
		EtlName: name,
		Payload: payload,
	}

	etlErr := runEtl(etlP)

	if etlErr == nil {
		etl.NewStandardOkResponse(c, etlP).SetStatus(http.StatusOK).Send()
	} else {
		ser := etl.NewStandardErrorResponse(etlP, etlErr)
		ser.SetStatus(http.StatusInternalServerError).Send("golang ETL error")
	}
}

func runEtl(etlP *etl.RunEtlParams) error {
	etlRow, err := etlP.Storage.GetEtlFromDb(etlP.EtlName)
	if err != nil {
		return err
	}

	etlP, err = insertDefaultParams(etlP)
	if err != nil {
		return err
	}

	switch etlRow.Kind {
	case constants.SQL:
		err := etlRunSql(etlP, etlRow, nil)
		if err != nil {
			return err
		}
	case constants.GOLANG:
		err := etlRunGolang(etlP, etlRow, nil)
		if err != nil {
			return err
		}
	case constants.STARLARK:
		err := etlRunStarlark(etlP, etlRow, nil)
		if err != nil {
			return err
		}

	case constants.SEQUENCE:
		// The name of the step will have been loaded into the context.

	default:
		msg := "unknown kind of etl: " + etlRow.Kind
		log.Println(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, nil)
			ser.SetStatus(http.StatusBadRequest).Send(msg)
		}
		return fmt.Errorf("%s: %s", msg, http.StatusText(http.StatusInternalServerError))
	}

	max_id, err := etlP.Storage.GetMaxId("get_max_etl_id", storage.EmbedParamMap{
		"name": etlP.EtlName,
	})
	if err != nil {
		return err
	}

	_, err = etlP.Storage.Exec(storage.Endpoint, "update_last_run", storage.EmbedParamMap{
		"key_id":   etlP.KeyId,
		"etl_id":   max_id,
		"etl_name": etlP.EtlName,
		"activity": "run etl via API",
	})

	if err != nil {
		msg := "could not update ETL metadata"
		log.Println(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, nil)
			ser.SetStatus(http.StatusInternalServerError).Send(msg)
		}
		return fmt.Errorf("%s: %s", msg, err.Error())
	}

	return nil
}

func InsertSummaryRows(source string, etlP *etl.RunEtlParams, summaries []etl.ItslogSummary) error {

	// Now, write them to the summary table.
	for _, summary := range summaries {

		etlP.Payload["key_id"] = etlP.KeyId
		// What date should this be?
		etlP.Payload["date"] = etlP.Storage.YYYYMMDD()
		etlP.Payload["operation"] = summary.Operation
		etlP.Payload["tags"] = summary.Tags
		etlP.Payload["value"] = summary.Value
		etlP.Payload["count"] = float64(summary.Count)
		etlP.Payload["hash"] = sql.NullString{String: summary.ReturnHash(), Valid: true}

		args, err := etlP.Storage.PrepareNamedArgs("insert_full_summary", etlP.Payload)
		if err != nil {
			return err
		}

		zap.L().Debug("insert summary rows",
			zap.String("args", fmt.Sprintf("%v", args)),
		)
		_, err = etlP.Storage.Endpoints.Exec("insert_full_summary", args)
		if err != nil {
			zap.L().Error("InsertSummaryRow Exec",
				zap.String("source", source),
				zap.Any("payload", etlP.Payload),
				zap.Error(err))
			return err
		}
	}

	return nil
}
