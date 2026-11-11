package endpoints

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
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

type SummaryRow struct {
	ID        int64     `json:"id"`
	Inserted  time.Time `json:"inserted"`
	KeyId     string    `json:"key_id"`
	Operation string    `json:"operation"`
	Tags      any       `json:"tags"`
	Data      any       `json:"data"`
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

	var summaryRow SummaryRow
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
