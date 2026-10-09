package endpoints

import (
	"fmt"
	"net/http"

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
	s, err := storage.SetupDB(appId, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not initialize storage backend",
			"date":    date,
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

	s, err := SetupGinDB(c, appId, body.Date)
	if err != nil {
		zap.L().Fatal("could not setup DB for CreateEtl")
	}

	_, err = s.Exec(storage.Endpoint, "insert_etl", storage.EmbedParamMap{
		"key_id": keyId,
		"name":   body.Name,
		"kind":   body.Kind,
		"body":   body.Body,
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
