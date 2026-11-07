package endpoints

import (
	"fmt"
	"net/http"
	"sort"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
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

	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)
	keyId := base.GetOrPanic(c, constants.ITSLOG_KEYID)

	s, err := SetupGinDB(c, storage.StorageConfig{
		AppId: appId,
		// We have to be able to create summaries in previous days.
		Date: body.Date,
		Kind: storage.LiveStorage,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":    "error",
			"method":    c.Request.Method,
			"message":   "could not set up database",
			"error":     err.Error(),
			"operation": body.Operation,
		})
		return
	}
	defer s.Close()

	// The tags field comes in as a JSON array. It needs to become
	// a sorted, dot-separated string.
	sort.Strings(body.Tags)
	theTags := strings.Join(body.Tags, ".")

	// Prep params for running the insert many operation
	etlP := &etl.RunEtlParams{
		AppId:   appId,
		GinCtx:  c,
		EtlName: "SummaryCreate",
		KeyId:   keyId,
		Storage: s,
		Payload: make(types.M, 0),
	}

	// We're only inserting one event, but it is about code reuse.
	summary := etl.ItslogSummary{
		KeyID:     keyId,
		Operation: body.Operation,
		Tags:      theTags,
		Data:      body.Data,
	}

	ierr := InsertSummaryRows("summarycreate", etlP, []etl.ItslogSummary{summary})

	if ierr != nil {
		zap.L().Error("summary save error", zap.Error(ierr))

		c.JSON(http.StatusNotImplemented, gin.H{
			"status":    "error",
			"method":    c.Request.Method,
			"message":   "could not save etl step",
			"operation": body.Operation,
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status":    "ok",
		"method":    c.Request.Method,
		"operation": body.Operation,
		"tags":      theTags,
		"data":      body.Data,
	})

}
