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

	// Expect all ETLs to return 0 or 1.
	sqlRow := callWithParams(etlP, etlRow.Body.String)

	var success int64 = -1
	err := sqlRow.Scan(&success)
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
