package endpoints

import (
	"encoding/base64"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func SetupGinDB(c *gin.Context, appId string, date string) (*storage.Storage, error) {
	sanitized, err := types.SanitizeDate(date)
	if err != nil {
		return nil, err
	}
	s, err := storage.SetupDB(appId, sanitized)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not initialize storage backend",
			"date":    sanitized,
		})
		return nil, err
	}
	return s, nil
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
