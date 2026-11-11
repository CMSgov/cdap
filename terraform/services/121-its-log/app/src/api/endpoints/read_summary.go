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
	Tags      []string `json:"tags"`
	Kind      string   `json:"kind" binding:"required,oneof=daily monthly full"`
	YYYYMMDD  string   `json:"ymd" binding:"omitempty,validateYMD"`
	Year      int      `json:"year" binding:"omitempty,gte=2000"`
	Month     int      `json:"month" binding:"omitempty,gte=1,lte=12"`
}

type SummaryRow struct {
	ID       int64     `json:"id"`
	Inserted time.Time `json:"inserted"`
	// Date      string         `json:"date"`
	KeyId     string `json:"key_id"`
	Operation string `json:"operation"`
	Tags      any    `json:"tags"`
	Data      any    `json:"data"`
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
	mp, err := getSummaryParams(app, body.Kind, body.YYYYMMDD, body.Year, body.Month)
	if err != nil {
		BadRequest(c, err, "could not set up database")
	}
	destination, err := getSummaryDB(mp)
	if err != nil {
		BadRequest(c, err, "cannot open database")
	}
	// Open the database we created.
	err = destination.Open(metabase.OpenExistingOnly)
	if err != nil {
		ServerError(c, errors.New("could not open summary database"), "cannot open summary db")
	}
	defer destination.Close()

	row := metabase.QueryRow(destination,
		embedfs.EmbeddedEndpoints.Files["read_summary"],
		embedfs.EmbedParamMap{
			"tags":      body.Tags,
			"operation": body.Operation,
		})

	if row.Err() != nil {
		zap.L().Error("read_summary exec error", zap.Error(row.Err()))
		BadRequest(c, row.Err(), "could not read summary")
	}

	var summaryRow SummaryRow
	scanErr := row.Scan(&summaryRow.Operation, &summaryRow.Tags, &summaryRow.Data)
	if scanErr != nil {
		zap.L().Info("error scanning summary row",
			zap.String("operation", body.Operation),
			zap.Any("tags", body.Tags),
			zap.Error(scanErr))
		response := gin.H{
			"status":  constants.OK,
			"message": "no summaries found",
		}
		c.JSON(http.StatusNoContent, response)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    constants.OK,
		"operation": summaryRow.Operation,
		"tags":      summaryRow.Tags,
		"data":      summaryRow.Data,
	})

}
