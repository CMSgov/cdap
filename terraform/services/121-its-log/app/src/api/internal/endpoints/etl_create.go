package endpoints

import (
	"encoding/base64"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

type EtlCreateSql struct {
	Name string `json:"name"`
	Kind string `json:"kind"`
	Body string `json:"body"`
	Date string `json:"date"`
}

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

func CreateEtl(c *gin.Context) {

	var body types.ETLPostBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	appId := base.GetOrPanic(c, "AppId")
	keyId := base.GetOrPanic(c, "KeyId")

	// Lets try and Base64 decode the string, to make sure it is good.
	decodedSQL, err := base64.StdEncoding.DecodeString(body.Body)
	if err != nil {
		zap.L().Info("failed to decode base64 string", zap.String("body", body.Body))
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": "could not decode Base64"})
		return
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
			c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": "ETLs cannot contain INSERT, DELETE, or UPDATE"})
			return
		}
	}

	// DuckDB wants Base64 values padded to mod(len, 4).
	// We'll make sure the padding is right, even though the client
	// should do this work.
	etl := strings.ReplaceAll(body.Body, "=", "")
	offset := len(etl) % 4
	if offset != 0 {
		for range 4 - offset {
			etl += "="
		}
	}

	s, err := SetupGinDB(c, appId, body.Date)
	if err != nil {
		return
	}
	defer s.Close()

	_, err = s.Exec(storage.Endpoint, "insert_etl", storage.EmbedParamMap{
		"key_id": keyId,
		"name":   body.Name,
		"kind":   body.Kind,
		"body":   etl,
	})

	if err != nil {
		zap.L().Error("etl save error", zap.Error(err))

		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not save ETL step",
			"date":    body.Date,
			"name":    body.Name,
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status": "ok",
		"method": c.Request.Method,
		"date":   body.Date,
		"name":   body.Name,
	})
}
