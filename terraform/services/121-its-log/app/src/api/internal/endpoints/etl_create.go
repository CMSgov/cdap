package endpoints

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
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

func CreateEtl(c *gin.Context) {

	var body types.ETLPostBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	// We need the AppId and KeyId, which the middleware attached
	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)
	keyId := base.GetOrPanic(c, constants.ITSLOG_KEYID)
	sanitized, _ := types.SanitizeDate(constants.TODAY)

	// We want to check the Base64 work that the client did.
	err := checkBase64Encoding(body.Body)
	if err != nil {
		zap.L().Info("failed base64 encoding check", zap.String("body", body.Body))
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": err.Error()})
		return
	}
	// And, pad it. DuckDB is very particular about its Base64 values.
	etl := padToMod4(body.Body)

	// Set up the database
	s, err := SetupGinDB(c, storage.StorageConfig{
		AppId: appId,
		Kind:  storage.LiveStorage,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": "error", "message": err.Error()})
		return
	}
	defer s.Close()

	// Run the code to insert the ETL into the database
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
			"date":    sanitized,
			"name":    body.Name,
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status": "ok",
		"method": c.Request.Method,
		"date":   sanitized,
		"name":   body.Name,
	})
}
