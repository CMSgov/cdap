package metabase

import (
	"database/sql"

	"go.uber.org/zap"
)

func ExecNoLock(im IMetabase, theSql string, params EmbedParamMap) (sql.Result, error) {
	args, err := PrepareNamedArgs(theSql, params)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil, err
	}

	res, err := im.GetDB().Exec(theSql, args...)
	if err != nil {
		zap.L().Error("ExecContext failure",
			zap.String("name", theSql),
			zap.Any("params", params),
			zap.Any("args", args),
			zap.Error(err))
	}
	return res, err

}

// ######## ##     ## ########  ######
// ##        ##   ##  ##       ##    ##
// ##         ## ##   ##       ##
// ######      ###    ######   ##
// ##         ## ##   ##       ##
// ##        ##   ##  ##       ##    ##
// ######## ##     ## ########  ######

func Exec(im IMetabase, theSql string, params EmbedParamMap) (sql.Result, error) {
	im.Lock("Exec")
	res, err := ExecNoLock(im, theSql, params)
	im.Flush()
	im.Unlock("Exec")
	return res, err
}
