package endpoints

import (
	"encoding/base64"
	"fmt"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func SetupGinDB(c *gin.Context, sc storage.StorageConfig) (*storage.Storage, error) {
	switch sc.Kind {
	case storage.LiveStorage:
		var sanitized string
		var err error
		if sc.Date != "" {
			// This should be the *exception*
			sanitized, err = types.SanitizeDate(sc.Date)
			zap.L().Info("creating storage from date",
				zap.String("date", sc.Date),
				zap.String("sanitized", sanitized))
			if err != nil {
				return nil, err
			}
		} else {
			sanitized, err = types.SanitizeDate(constants.TODAY)
		}

		s, err := storage.SetupDB(sc.AppId, sanitized, storage.LiveStorage)
		if err != nil {
			return nil, err
		}
		s.Kind = sc.Kind
		return s, nil
	case storage.ArchiveStorage:
		zap.L().Debug("setting up archive storage")
		s, err := storage.SetupDB(sc.AppId, sc.Date, storage.ArchiveStorage)
		if err != nil {
			return nil, err
		}
		s.Kind = sc.Kind
		return s, nil
	case storage.ConsolidatedStorage:
		zap.L().Debug("setting up consolidated storage")
		s, err := storage.SetupDB(sc.AppId, constants.CONSOLIDATED, storage.ConsolidatedStorage)
		if err != nil {
			return nil, err
		}
		s.Kind = sc.Kind
		return s, nil
	default:
		return nil, fmt.Errorf("cannot setup db; unknown kind: %d", sc.Kind)
	}
}

func padToMod4(toPad string) string {
	// DuckDB wants Base64 values padded to mod(len, 4).
	// We'll make sure the padding is right, even though the client
	// should do this work.
	etl := strings.ReplaceAll(toPad, "=", "")
	offset := len(etl) % 4
	if offset != 0 {
		for range 4 - offset {
			etl += "="
		}
	}
	return etl
}

func checkBase64Encoding(body string) error {
	// Lets try and Base64 decode the string, to make sure it is good.
	decodedSQL, err := base64.StdEncoding.DecodeString(body)
	if err != nil {
		return fmt.Errorf("could not decode base64: %s", err.Error())
	}
	theSql := strings.ToLower(string(decodedSQL))
	// And, for fun: let's make sure the words "delete" or "update"
	// do not appear anywhere in this ETL. We don't want ETLs to be able to
	// delete data.
	for _, notAllowed := range []string{"insert", "delete", "update"} {
		if strings.Contains(theSql, notAllowed) {
			zap.L().Info("naughty things in sql",
				zap.String("sql", theSql),
				zap.String("not_allowed", notAllowed))
			return fmt.Errorf("etls cannot contain insert, delete, or update")
		}
	}
	return nil
}
