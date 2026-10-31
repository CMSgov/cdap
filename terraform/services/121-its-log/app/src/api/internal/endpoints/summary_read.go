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

type SummaryReadBody struct {
	Date      string `json:"date" binding:"required"`
	Tags      string `json:"tags" binding:"required"`
	Operation string `json:"operation" binding:"required"`
}

func SummaryRead(c *gin.Context) {
	var body SummaryReadBody
	// Call ShouldBindJSON to bind the incoming JSON to the newItem struct
	if err := c.ShouldBindJSON(&body); err != nil {
		// If an error occurs (e.g., invalid JSON, missing required fields),
		// return a 400 Bad Request error
		zap.L().Error("should bind", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	appId := base.GetOrPanic(c, "AppId")

	s, err := SetupGinDB(c, appId, body.Date)
	if err != nil {
		return
	}
	defer s.Close()

	etlP := etl.RunEtlParams{
		EtlName: "SummaryRead",
		GinCtx:  c,
		Storage: s,
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
		msg := "could not parse date; must be YYYY-MM-DD"
		ser := etl.NewStandardErrorResponse(&etlP, err)
		ser.SetStatus(http.StatusNotFound).Send(msg)
		return
	}

	var summaryRow types.SummaryRow
	row.Scan(&summaryRow.Date, &summaryRow.Operation, &summaryRow.Tags, &summaryRow.Value, &summaryRow.Count)
	if row.Err() != nil {
		zap.L().Error("read_summary row scan", zap.Error(err))
		msg := fmt.Sprintf("no summary found for %s", body.Operation)
		ser := etl.NewStandardErrorResponse(&etlP, err)
		ser.SetStatus(http.StatusNotFound).Send(msg)
	}
	response := gin.H{
		"status":    constants.OK,
		"date":      summaryRow.Date,
		"operation": summaryRow.Operation,
		"value":     summaryRow.Value,
		"tags":      summaryRow.Tags,
		"count":     summaryRow.Count,
	}

	// Cleanup the sql.NullString values
	if summaryRow.Value.Valid {
		response["value"] = summaryRow.Value.String
	} else {
		response["value"] = nil
	}
	if summaryRow.Tags.Valid {
		response["tags"] = summaryRow.Tags.String
	} else {
		response["tags"] = nil
	}
	c.JSON(http.StatusOK, response)

}
