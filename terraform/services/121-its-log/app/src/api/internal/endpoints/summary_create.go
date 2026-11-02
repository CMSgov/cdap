package endpoints

import (
	"fmt"
	"net/http"
	"sort"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func SummaryCreate(c *gin.Context) {

	var body types.SummaryPostBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	appId := base.GetOrPanic(c, "AppId")
	keyId := base.GetOrPanic(c, "KeyId")
	sanitized, err := types.SanitizeDate(body.Date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "bad date",
			"date":    sanitized,
		})
	}
	s, err := SetupGinDB(c, appId, sanitized)
	if err != nil {
		return
	}
	defer s.Close()

	// The tags field comes in as a JSON array. It needs to become
	// a sorted, dot-separated string.
	sort.Strings(body.Tags)
	theTags := strings.Join(body.Tags, ".")
	etlP := &etl.RunEtlParams{
		AppId:   appId,
		GinCtx:  c,
		EtlName: "SummaryCreate",
		KeyId:   keyId,
		Storage: s,
		Payload: make(types.M, 0),
	}
	summary := etl.ItslogSummary{
		KeyID:     keyId,
		Date:      sanitized,
		Operation: body.Operation,
		Tags:      theTags,
		Data:      body.Data,
	}

	InsertSummaryRows("summarycreate", etlP, []etl.ItslogSummary{summary})

	// _, err = s.Exec(storage.Endpoint, "insert_full_summary", storage.EmbedParamMap{
	// 	"key_id":    keyId,
	// 	"date":      body.Date,
	// 	"operation": body.Operation,
	// 	"tags":      theTags,
	// 	"data":      body.Data,
	// })

	if err != nil {
		zap.L().Error("summary save error", zap.Error(err))

		c.JSON(http.StatusNotImplemented, gin.H{
			"status":    "error",
			"method":    c.Request.Method,
			"message":   "could not save etl step",
			"date":      sanitized,
			"operation": body.Operation,
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status":    "ok",
		"method":    c.Request.Method,
		"date":      sanitized,
		"operation": body.Operation,
		"tags":      theTags,
		"data":      body.Data,
	})

}
