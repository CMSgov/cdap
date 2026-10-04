package endpoints

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"go.uber.org/zap"
)

// This is the handler if we call it directly from the API.
// We only get the gin context.
func RunEtl(c *gin.Context) {
	appId := base.GetOrPanic(c, "AppId")
	keyId := base.GetOrPanic(c, "KeyId")
	date := c.Param("date")
	name := c.Param("name")

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

	s, err := SetupGinDB(c, appId, date)
	if err != nil {
		zap.L().Fatal("could not setup DB for RunEtl")
	}

	dateErr := s.SetDateYMD(date)
	etlP := &etl.RunEtlParams{
		AppId:   appId,
		KeyId:   keyId,
		GinCtx:  c,
		Storage: s,
		EtlName: name,
		Payload: payload,
	}

	// FUTURE IMPROVEMENT: Could this pattern be used in etl_create?
	if dateErr != nil {
		ser := etl.NewStandardErrorResponse(etlP, dateErr)
		ser.SetStatus(http.StatusInternalServerError).Send("could not parse date; must be YYYY-MM-DD")
		return
	}

	s.InitDB()

	etlErr := runEtl(etlP)

	if etlErr == nil {
		etl.NewStandardOkResponse(c, etlP).SetStatus(http.StatusOK).Send()
	} else {
		ser := etl.NewStandardErrorResponse(etlP, etlErr)
		ser.SetStatus(http.StatusInternalServerError).Send("golang ETL error")
	}
}

func runEtl(etlP *etl.RunEtlParams) error {
	// FIXME SQL CALL
	//row, err := etlP.Storage.Queries.GetETL(context.Background(), etlP.EtlName)
	raw := etlP.Storage.QueryRow(storage.Endpoint,
		"get_etl",
		storage.EmbedParamMap{"name": etlP.EtlName})

	// var name, kind, body, lastRun string
	//err := row.Scan(&name, &kind, &body, &lastRun)
	var row etl.GetETLRow
	err := raw.Scan(&row.Name, &row.Kind, &row.Body, &row.LastRun)

	if err != nil {
		msg := "could not find/scan ETL step"
		zap.L().Error(msg,
			zap.String("etl_name", etlP.EtlName),
			zap.Any("payload", etlP.Payload))
		return fmt.Errorf("%s: %s", msg, err.Error())
	}

	switch row.Kind {
	case "sql":
		err := etlRunSql(etlP, row, nil)
		if err != nil {
			return err
		}
	case "golang":
		err := etlRunGolang(etlP, row, nil)
		if err != nil {
			return err
		}
	case "starlark":
		err := etlRunStarlark(etlP, row, nil)
		if err != nil {
			return err
		}

	case "sequence":
		// The name of the step will have been loaded into the context.

	default:
		msg := "unknown kind of etl: " + row.Kind
		log.Println(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, nil)
			ser.SetStatus(http.StatusInternalServerError).Send(msg)
		}
		return fmt.Errorf("%s: %s", msg, http.StatusText(http.StatusInternalServerError))
	}

	// FIXME SQL CALL
	//updateErr := etlP.Storage.Queries.UpdateLastRun(context.Background(), etlP.EtlName)
	updateErr := errors.New("FIXME")

	if updateErr != nil {
		msg := "could not update ETL metadata"
		log.Println(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, nil)
			ser.SetStatus(http.StatusInternalServerError).Send(msg)
		}
		return fmt.Errorf("%s: %s", msg, updateErr.Error())
	}

	return nil
}
