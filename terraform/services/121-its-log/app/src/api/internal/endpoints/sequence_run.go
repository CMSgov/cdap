package endpoints

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// Run a sequence immediately, synchronously.
func SequenceRun(c *gin.Context) {
	appId := base.GetOrPanic(c, "AppId")
	keyId := base.GetOrPanic(c, "KeyId")
	// sequenceName := c.Param("name")
	// sequenceDate := c.Param("date")

	// // ETL steps can have an arbitrary POST body?
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		body = []byte("{}")
	}
	payload := make(map[string]any)
	jsonErr := json.Unmarshal(body, &payload)
	if jsonErr != nil {
		payload = make(map[string]any)
	}

	for _, key := range []string{"name", "date"} {
		if _, ok := payload[key]; !ok {
			c.JSON(http.StatusBadRequest, gin.H{
				"status":  "error",
				"method":  c.Request.Method,
				"message": key + " must be present in the body",
			})
			return
		}
	}
	sequenceName := payload["name"].(string)
	sequenceDate := payload["date"].(string)

	s, err := storage.NewStorage(appId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not initialize storage backend",
			"date":    sequenceDate,
			"name":    sequenceName,
		})
		return
	}
	defer s.Close()

	dateErr := s.SetDateYMD(sequenceDate)
	if dateErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not parse date; must be YYYY-MM-DD",
			"date":    sequenceDate,
			"name":    sequenceName,
		})
		return
	}
	s.InitDB()

	seq, err := s.GetEtlFromDb(sequenceName)
	if err != nil {
		zap.L().Error("get sequence from db", zap.Error(err))
	}

	// Sequences are JSON.
	// [ { name: "count-total" }, { name: "consolidate", params: { ... } } ]
	var seqEntries []types.SequenceEntry
	jsonErr2 := json.Unmarshal([]byte(seq.Body), &seqEntries)
	if jsonErr2 != nil {
		msg := fmt.Sprintf("malformed sequence spec: %s", seq.Body)
		log.Println(msg)
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": msg,
			"date":    s.YYYYMMDD(),
			"name":    sequenceName,
		})
		return
	}

	for _, step := range seqEntries {
		// Merge the passed-in payload with whatever is defined for this step.
		merged := make(map[string]any)
		for k, v := range payload {
			merged[k] = v
		}
		if step.Params != nil {
			for k, v := range step.Params {
				merged[k] = v
			}
		}

		sequenceError := runEtl(&etl.RunEtlParams{
			AppId:   appId,
			KeyId:   keyId,
			GinCtx:  nil,
			Storage: s,
			EtlName: step.Name,
			Payload: merged,
		})

		if sequenceError != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"method":  c.Request.Method,
				"message": fmt.Sprintf("error in sequence execution: %s", step.Name),
				"detail":  sequenceError.Error(),
				"date":    sequenceDate,
				"name":    step.Name,
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
