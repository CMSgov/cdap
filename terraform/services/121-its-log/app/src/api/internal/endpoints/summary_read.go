package endpoints

import (
	"database/sql"
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
	row.Scan(&summaryRow.Date, &summaryRow.Operation, &summaryRow.Tags, &summaryRow.Data)
	if row.Err() != nil {
		zap.L().Error("read_summary row scan", zap.Error(err))
		msg := fmt.Sprintf("no summary found for %s", body.Operation)
		ser := etl.NewStandardErrorResponse(&etlP, err)
		ser.SetStatus(http.StatusNotFound).Send(msg)
	}

	// Clean up the response; don't send back NULL/nil/None values.
	if summaryRow.Data == nil {
		summaryRow.Data = make(map[string]any, 0)
	}
	if summaryRow.Tags.Valid == false {
		summaryRow.Tags = sql.NullString{Valid: true, String: ""}
	}

	response := gin.H{
		"status":    constants.OK,
		"date":      summaryRow.Date,
		"operation": summaryRow.Operation,
		"tags":      summaryRow.Tags.String,
		"data":      summaryRow.Data,
	}

	c.JSON(http.StatusOK, response)

}
