package endpoints

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func checkTheBody(c *gin.Context, body types.ETLPostBody) (string, error) {
	// This conditional is because we're using CreateEtl for both
	// strings (unstructured data) and JSON (structured data). The strings
	// are for SQL and starlark, and the JSON is for sequences.
	// This could be changed in time, so all ETLs are JSON, and include both
	// a "body" element and an "expected-params" element, so that we could
	// "automate" the detection of what parameters are required for each ETL.
	theBody := ""
	var err error = nil

	switch body.Body.(type) {
	case string:
		if body.Kind == "sql" || body.Kind == "starlark" {
			theBody = body.Body.(string)
		} else {
			err = errors.New("only SQL ETL actions may come in as a string")
			break
		}
	case []any:
		if body.Kind == "sequence" {
			// Make sure it is an array of objects with "name"
			// FIXME: the typing on these could lead to 500s if it is wrong.
			for _, e := range body.Body.([]any) {
				isOk := true
				for _, k := range []string{"name"} {
					if _, ok := e.(map[string]any)[k]; !ok {
						isOk = false
					}
				}
				if !isOk {
					err = errors.New("missing `name` from sequence object")
					break
				}
			}
			jsonData, err := json.MarshalIndent(body.Body, "", "  ")
			if err != nil {
				err = errors.New("body contains invalid JSON")
				break
			}
			theBody = string(jsonData)
		} else {
			err = errors.New("sequences must come in as an array of JSON objects")
			break
		}
	default:
		log.Println(body.Body)
		err = fmt.Errorf("body contains something of an unrecognizable type: %T", body.Body)
		break
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": err.Error(),
			"date":    body.Date,
			"name":    body.Name,
		})
		return "", err
	}

	return theBody, nil
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

	theBody, err := checkTheBody(c, body)
	if err != nil {
		return
	}

	_, err = s.Exec(storage.Endpoint, "insert_etl", storage.EmbedParamMap{
		"key_id": keyId,
		"name":   body.Name,
		"kind":   body.Kind,
		"body":   theBody,
	})
	if err != nil {
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
