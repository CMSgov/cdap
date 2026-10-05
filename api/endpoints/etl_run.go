package endpoints

import (
	"encoding/json"
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
	// There is a lock burried down the call tree...
	// etlP.Storage.Lock("runEtl")
	etlRow, err := etlP.Storage.GetEtlFromDb(etlP.EtlName)
	// etlP.Storage.Unlock("runEtl")
	if err != nil {
		return err
	}

	etlP = insertDefaultParams(etlP)

	switch etlRow.Kind {
	case "sql":
		err := etlRunSql(etlP, etlRow, nil)
		if err != nil {
			return err
		}
	case "golang":
		err := etlRunGolang(etlP, etlRow, nil)
		if err != nil {
			return err
		}
	case "starlark":
		err := etlRunStarlark(etlP, etlRow, nil)
		if err != nil {
			return err
		}

	case "sequence":
		// The name of the step will have been loaded into the context.

	default:
		msg := "unknown kind of etl: " + etlRow.Kind
		log.Println(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, nil)
			ser.SetStatus(http.StatusInternalServerError).Send(msg)
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
