package endpoints

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/http"

	"github.com/navapbc/its-log/internal/constants"
	etl "github.com/navapbc/its-log/internal/etl"
	etlgo "github.com/navapbc/its-log/internal/etl/golang"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func callWithParams(etlP *etl.RunEtlParams, theSql string) *sql.Row {
	args, err := etlP.Storage.PrepareNamedArgs(etlP.EtlName, etlP.Payload)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil
	}

	etlP.Storage.Lock("callWithParams")
	etlRow := etlP.Storage.GetDB().QueryRow(theSql, args...)
	etlP.Storage.Unlock("callWithParams")

	return etlRow
}

func insertDefaultParams(etlP *etl.RunEtlParams) (*etl.RunEtlParams, error) {
	payload := etlP.Payload
	payload["key_id"] = etlP.KeyId
	payload["app_id"] = etlP.AppId
	// If the date is in the payload, and it is today or yesterday, convert it.
	if v, ok := payload["date"]; ok {
		date, err := types.SanitizeDate(v.(string))
		if err != nil {
			msg := "default parameter for date failed to parse"
			zap.L().Error(msg,
				zap.String("date", v.(string)))
			return nil, errors.New(msg)
		}
		payload["date"] = date
	} else {
		// If it was not in the payload, assume it is today.
		payload["date"] = types.NewILTimeToday().AsYYYYMMDD()
	}
	etlP.Payload = payload
	return etlP, nil
}

func etlRunSql(etlP *etl.RunEtlParams, etlRow storage.EtlRow, tx *sql.Tx) error {
	// Run the query
	if !etlRow.Body.Valid {
		msg := "sql is null for ETL step"
		zap.L().Error(msg)
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, errors.New(msg))
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
	etlP.Payload["etl_id"] = max_id

	// Expect all ETLs to return 0 or 1.
	sqlRow := callWithParams(etlP, etlRow.Body.String)
	if sqlRow.Err() != nil {
		zap.L().Error("callWithParams failed",
			zap.Error(sqlRow.Err()))
		return sqlRow.Err()
	}

	var success int64 = -1
	err = sqlRow.Scan(&success)
	switch err {
	case sql.ErrNoRows:
		log.Println("No rows were returned!")
	case nil:
		if success == constants.ETL_SUCCESS_VALUE {
			return nil
		} else {
			return fmt.Errorf("expected %d; %s returned %v", constants.ETL_SUCCESS_VALUE, etlRow.Name, success)
		}
	default:
		msg := err.Error()
		if etlP.GinCtx != nil {
			ser := etl.NewStandardErrorResponse(etlP, err)
			ser.SetStatus(http.StatusInternalServerError).Send(msg)
		}
		//log.Println(msg)
		return fmt.Errorf("%s: %s", msg, http.StatusText(http.StatusInternalServerError))
	}

	return nil
}

func etlRunGolang(etlP *etl.RunEtlParams, row storage.EtlRow, tx *sql.Tx) error {
	functionName := row.Name
	if function, ok := etlgo.GolangETLMap[functionName]; ok {
		// Like the SQL actions, lock/unlock around what we do.
		// This saves the Golang ETLs from having to manage locks internal
		// to each individual action.
		etlP.Storage.Lock("etlRunGolang")
		err := function(etlP)
		etlP.Storage.Unlock("etlRunGolang")
		if err != nil {
			return err
		}
	} else {
		// FIXME: we need to pass an error back.
		fmt.Printf("Function %s not found\n", functionName)
	}

	return nil
}
