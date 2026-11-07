package endpoints

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func SummaryRead(c *gin.Context) {
	var body types.SummaryReadBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		zap.L().Error("should bind", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)
	keyId := base.GetOrPanic(c, constants.ITSLOG_KEYID)

	s, err := SetupGinDB(c, storage.StorageConfig{
		AppId: appId,
		Date:  body.Date,
		Kind:  storage.LiveStorage,
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

	etlP := etl.RunEtlParams{
		EtlName: "SummaryRead",
		GinCtx:  c,
		Storage: s,
		KeyId:   keyId,
	}

	args, err := s.PrepareNamedArgs("read_summary", storage.EmbedParamMap{
		"tags":      body.Tags,
		"operation": body.Operation,
	})
	if err != nil {
		zap.L().Error("read_summary arg prep error", zap.Error(err))
	}
	row := s.Endpoints.QueryRow("read_summary", args)
	if err != nil {
		zap.L().Error("read_summary exec error", zap.Error(err))
		ser := etl.NewStandardErrorResponse(&etlP, err)
		ser.SetStatus(http.StatusInternalServerError).Send("could not read summary")
		return
	}

	var summaryRow types.SummaryRow
	scanErr := row.Scan(&summaryRow.Operation, &summaryRow.Tags, &summaryRow.Data)
	if scanErr != nil {
		msg := fmt.Sprintf("no summary found for %s", body.Operation)
		zap.L().Info(msg)
		response := gin.H{
			"status":  constants.OK,
			"message": msg,
		}
		c.JSON(http.StatusNoContent, response)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    constants.OK,
		"operation": summaryRow.Operation,
		"tags":      summaryRow.Tags.String,
		"data":      summaryRow.Data,
	})

}
