package endpoints

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/constants"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/embedfs"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type SummaryReadBody struct {
	Operation string   `json:"operation" binding:"required"`
	Tags      []string `json:"tags" binding:"validateArrString"`
	Kind      string   `json:"kind" binding:"required,oneof=daily monthly yearly full"`
	YMD       string   `json:"ymd" binding:"omitempty,validateYMD"`
	Year      int      `json:"year" binding:"omitempty,gte=2000"`
	Month     int      `json:"month" binding:"omitempty,gte=1,lte=12"`
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
	app := types.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	// The destination will depend on the kind of consolidation source
	// we are dealing with.
	sdbsp, err := getSummaryDbSetupParams(app, body.Kind, body.YMD, body.Year, body.Month)
	if err != nil {
		BadRequest(c, err, "could not set up database")
		return
	}
	destination, err := getSummaryDB(sdbsp)
	if err != nil {
		BadRequest(c, err, "cannot open database")
		return
	}
	// Open the database
	err = destination.Open(metabase.OpenExistingOnly)
	if err != nil {
		ServerError(c, errors.New("could not open summary database"), "cannot open summary db")
		return
	}
	defer destination.Close()

	params := []embedfs.EmbeddedParam{
		{Name: "tags", Value: body.Tags, Type: embedfs.EmbeddedRaw},
		{Name: "operation", Value: body.Operation, Type: embedfs.EmbeddedString},
	}
	row := metabase.QueryRow(destination,
		embedfs.EmbeddedEndpoints.Files["read_summary"],
		params)

	if row.Err() != nil {
		zap.L().Error("read_summary exec error", zap.Error(row.Err()))
		BadRequest(c, row.Err(), "could not read summary")
		return
	}

	var summaryRow types.SummaryRow
	scanErr := row.Scan(&summaryRow.Operation, &summaryRow.Tags, &summaryRow.Data)
	if scanErr != nil {
		zap.L().Info("error scanning summary row",
			zap.String("operation", body.Operation),
			zap.Any("tags", body.Tags),
			zap.Error(scanErr))
		ContentNotFound(c, scanErr, "no summary found")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    constants.OK,
		"operation": summaryRow.Operation,
		"tags":      summaryRow.Tags,
		"data":      summaryRow.Data,
	})

}
