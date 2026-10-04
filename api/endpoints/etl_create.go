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

// func checkTheBody(c *gin.Context, body string) (string, error) {
// 	// FIXME: for now, make sure it base64 decodes.
// 	// More checking can be done on the various types of ETL that are inserted.
// 	// DuckDB expects B64 to be a multiple of 4.
// 	if len(body)%4 != 0 {
// 		return "", fmt.Errorf("b64 encoded body must be of length %4; len: %d", len(body)%4)
// 	}

// 	_, err := base64.StdEncoding.DecodeString(body)
// 	if err != nil {
// 		return "", fmt.Errorf("b64 encoded string will not decode with standard encoder")
// 	}

// 	return body, nil
// }

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

	// theBody, err := checkTheBody(c, body.Body)
	// if err != nil {
	// 	return
	// }

	// Get rid of all newlines if it is an SQL ETL
	// standardEncoded := strings.ReplaceAll(theBody, "\n", " ")
	// Base64 encode the body.
	// standardEncoded := base64.StdEncoding.EncodeToString([]byte(theBody))
	// DuckDB wants this padded to a multiple of four
	// standardEncoded = standardEncoded + strings.Repeat("=", (4-(len(standardEncoded)%4))%4)

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

// // Lets find out what this is.
// var raw map[string]json.RawMessage
// if err := json.Unmarshal(body.Body.([]byte), &raw); err != nil {
// 	return "", errors.New("could not unmarshall CreateEtl body")
// }
// // It must be JSON
// // Lets see if it has a "kind" key.
// if _, ok := raw["kind"]; !ok {
// 	return "", errors.New("CreateEtl payload missing a `kind` key")
// }
// // Let's say it is good.

// switch string(raw["kind"]) {
// case "sql":
// 	var createSql EtlCreateSql
// 	if err := json.Unmarshal(body.Body.([]byte), &createSql); err != nil {
// 		return "", errors.New("bad create SQL payload")
// 	}

// case "sequence":
// 	break
// }

// // switch body.Body.(type) {
// // case string:
// // 	if body.Kind == "sql" || body.Kind == "starlark" {
// // 		theBody = body.Body.(string)
// // 	} else {
// // 		err = errors.New("only SQL ETL actions may come in as a string")
// // 		break
// // 	}
// // case []any:
// // 	if body.Kind == "sql" {

// // 	}
// // 	if body.Kind == "sequence" {
// // 		listof_elements, ok := body.Body.([]any)
// // 		if !ok {
// // 			err = errors.New("body does not contain a list of elements")
// // 			break
// // 		}

// // 		for _, e := range listof_elements {
// // 			isOk := true
// // 			for _, k := range []string{"name"} {
// // 				if _, ok := e.(map[string]any)[k]; !ok {
// // 					isOk = false
// // 				}
// // 			}
// // 			if !isOk {
// // 				err = errors.New("missing `name` from at least one sequence object")
// // 				break
// // 			}
// // 		}
// // 		jsonData, err := json.MarshalIndent(body.Body, "", "  ")
// // 		if err != nil {
// // 			err = errors.New("body contains invalid JSON")
// // 			break
// // 		}
// // 		theBody = string(jsonData)
// // 	} else {
// // 		err = errors.New("sequences must come in as an array of JSON objects")
// // 		break
// // 	}
// // default:
// // 	log.Println(body.Body)
// // 	err = fmt.Errorf("body contains something of an unrecognizable type: %T", body.Body)
// // }

// if err != nil {
// 	zap.L().Error("error parsing ETL body",
// 		zap.Error(err))
// 	c.JSON(http.StatusInternalServerError, gin.H{
// 		"status":  "error",
// 		"method":  c.Request.Method,
// 		"message": err.Error(),
// 		"date":    body.Date,
// 		"name":    body.Name,
// 	})
// 	return "", err
// }
