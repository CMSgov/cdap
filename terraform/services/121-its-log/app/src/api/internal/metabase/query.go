package metabase

import (
	"database/sql"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/embedfs"
	"go.uber.org/zap"
)

//  #######  ##     ## ######## ########  ##    ##
// ##     ## ##     ## ##       ##     ##  ##  ##
// ##     ## ##     ## ##       ##     ##   ####
// ##     ## ##     ## ######   ########     ##
// ##  ## ## ##     ## ##       ##   ##      ##
// ##    ##  ##     ## ##       ##    ##     ##
//  ##### ##  #######  ######## ##     ##    ##

func Query(m *Metabase, theSql string, params []embedfs.EmbeddedParam) (*sql.Rows, error) {

	m.Lock("Query")
	res, err := QueryNoLock(m, theSql, params)
	m.Unlock("Query")
	return res, err
}

func QueryNoLock(m *Metabase, theSql string, params []embedfs.EmbeddedParam) (*sql.Rows, error) {

	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil, err
	}
	res, err := m.GetDB().Query(theSql, args)
	if err != nil {
		return nil, err
	}
	return res, nil

}

//  #######  ##     ## ######## ########  ##    ## ########   #######  ##      ##
// ##     ## ##     ## ##       ##     ##  ##  ##  ##     ## ##     ## ##  ##  ##
// ##     ## ##     ## ##       ##     ##   ####   ##     ## ##     ## ##  ##  ##
// ##     ## ##     ## ######   ########     ##    ########  ##     ## ##  ##  ##
// ##  ## ## ##     ## ##       ##   ##      ##    ##   ##   ##     ## ##  ##  ##
// ##    ##  ##     ## ##       ##    ##     ##    ##    ##  ##     ## ##  ##  ##
//  ##### ##  #######  ######## ##     ##    ##    ##     ##  #######   ###  ###

func QueryRow(m *Metabase, theSql string, params []embedfs.EmbeddedParam) *sql.Row {
	var row *sql.Row
	m.Lock("QueryRow")

	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		m.Unlock("QueryRow")
		return nil
	}
	row = m.GetDB().QueryRow(theSql, args...)
	m.Unlock("QueryRow")

	return row
}
