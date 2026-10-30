package endpoints

import (
	"database/sql"
	"fmt"

	"github.com/navapbc/its-log/internal/etl"
	etlgo "github.com/navapbc/its-log/internal/etl/golang"
	"github.com/navapbc/its-log/internal/storage"
)

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
