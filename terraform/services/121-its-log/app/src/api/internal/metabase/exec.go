package metabase

import (
	"database/sql"
	"strings"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/embedfs"
	"go.uber.org/zap"
)

func ExecNoLock(im *Metabase, theSql string, params []embedfs.EmbeddedParam) (sql.Result, error) {
	var args []any = make([]any, 0)
	var err error

	if !strings.Contains(theSql, "-- SCHEMA") {
		args, err = PrepareNamedArgs(theSql, params)
		if err != nil {
			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
			return nil, err
		}
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

func Exec(im *Metabase, theSql string, params []embedfs.EmbeddedParam) (sql.Result, error) {
	im.Lock("Exec")
	res, err := ExecNoLock(im, theSql, params)
	im.Flush()
	im.Unlock("Exec")
	return res, err
}
