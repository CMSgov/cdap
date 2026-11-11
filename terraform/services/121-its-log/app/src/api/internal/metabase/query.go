package metabase

import (
	"database/sql"

	"github.com/navapbc/its-log/internal/embedfs"
	"go.uber.org/zap"
)

//  #######  ##     ## ######## ########  ##    ##
// ##     ## ##     ## ##       ##     ##  ##  ##
// ##     ## ##     ## ##       ##     ##   ####
// ##     ## ##     ## ######   ########     ##
// ##  ## ## ##     ## ##       ##   ##      ##
// ##    ##  ##     ## ##       ##    ##     ##
//  ##### ##  #######  ######## ##     ##    ##

func Query(m *Metabase, theSql string, params embedfs.EmbedParamMap) (*sql.Rows, error) {

	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil, err
	}
	m.Lock("Query")
	res, err := m.GetDB().Query(theSql, args)
	m.Unlock("Query")
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

func QueryRow(m *Metabase, theSql string, params embedfs.EmbedParamMap) *sql.Row {
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
