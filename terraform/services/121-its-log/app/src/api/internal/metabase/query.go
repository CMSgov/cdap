package metabase

import (
	"database/sql"

	"go.uber.org/zap"
)

//  #######  ##     ## ######## ########  ##    ##
// ##     ## ##     ## ##       ##     ##  ##  ##
// ##     ## ##     ## ##       ##     ##   ####
// ##     ## ##     ## ######   ########     ##
// ##  ## ## ##     ## ##       ##   ##      ##
// ##    ##  ##     ## ##       ##    ##     ##
//  ##### ##  #######  ######## ##     ##    ##

func Query(im IMetabase, theSql string, params EmbedParamMap) (*sql.Rows, error) {

	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil, err
	}
	im.Lock("Query")
	res, err := im.GetDB().Query(theSql, args)
	im.Unlock("Query")
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

func QueryRow(im IMetabase, theSql string, params EmbedParamMap) *sql.Row {
	var row *sql.Row
	im.Lock("QueryRow")
	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		im.Unlock("QueryRow")
		return nil
	}
	if err != nil {
		zap.L().Error("could not get embedded sql for query",
			zap.Error(err))
		return nil
	}
	row = im.GetDB().QueryRow(theSql, args...)
	im.Unlock("QueryRow")

	return row
}
