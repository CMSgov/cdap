package endpoints

import (
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
)

type SummaryPostBody struct {
	Operation string   `json:"operation" binding:"required"`
	Tags      []string `json:"tags"`
	Data      any      `json:"data" binding:"required"`
	Kind      string
	YYYYMMDD  string `json:"ymd"`
}

func SummaryCreate(c *gin.Context) {

	var body SummaryPostBody
	if err := c.ShouldBindJSON(&body); err != nil {
		BadRequest(c, err, "JSON did not bind")
		return
	}

	// Summaries are either daily, weekly, yearly, or consolidated
	body.Kind = base.GetParamOrPanic(c, "kind", SUMMARY_ALLOWED_KINDS)

	app := metabase.App{
		AppId: base.GetOrPanic(c, constants.ITSLOG_APPID),
		KeyId: base.GetOrPanic(c, constants.ITSLOG_KEYID),
	}

	var im metabase.IMetabase
	var err error
	switch body.Kind {
	case "daily":
		err = types.IsValidYYYYMMDD(body.YYYYMMDD)
		if err != nil {
			BadRequest(c, err, "invalid YYYY-MM-DD")
		}
		im, err = metabase.NewDailyDatabase(
			app,
			body.YYYYMMDD,
		)
		if err != nil {
			ServerError(c, err, "could not create daily database")
		}
		err = im.Open(metabase.OpenExistingOnly)
		if err != nil {
			BadRequest(c, err, fmt.Sprintf("no daily database exists %s", body.YYYYMMDD))
		}
	}

	StatusOk(c, "summary created")

	// s, err := SetupGinDB(c, storage.StorageConfig{
	// 	AppId: appId,
	// 	// We have to be able to create summaries in previous days.
	// 	Date: body.Date,
	// 	Kind: storage.LiveStorage,
	// })
	// if err != nil {
	// 	c.JSON(http.StatusInternalServerError, gin.H{
	// 		"status":    "error",
	// 		"method":    c.Request.Method,
	// 		"message":   "could not set up database",
	// 		"error":     err.Error(),
	// 		"operation": body.Operation,
	// 	})
	// 	return
	// }
	// defer s.Close()

	// // The tags field comes in as a JSON array. It needs to become
	// // a sorted, dot-separated string.
	// sort.Strings(body.Tags)
	// theTags := strings.Join(body.Tags, ".")

	// // Prep params for running the insert many operation
	// etlP := &etl.RunEtlParams{
	// 	AppId:   appId,
	// 	GinCtx:  c,
	// 	EtlName: "SummaryCreate",
	// 	KeyId:   keyId,
	// 	Storage: s,
	// 	Payload: make(types.M, 0),
	// }

	// // We're only inserting one event, but it is about code reuse.
	// summary := etl.ItslogSummary{
	// 	KeyID:     keyId,
	// 	Operation: body.Operation,
	// 	Tags:      theTags,
	// 	Data:      body.Data,
	// }

	// ierr := InsertSummaryRows("summarycreate", etlP, []etl.ItslogSummary{summary})

	// if ierr != nil {
	// 	zap.L().Error("summary save error", zap.Error(ierr))

	// 	c.JSON(http.StatusNotImplemented, gin.H{
	// 		"status":    "error",
	// 		"method":    c.Request.Method,
	// 		"message":   "could not save etl step",
	// 		"operation": body.Operation,
	// 	})
	// 	return
	// }

	// c.JSON(http.StatusCreated, gin.H{
	// 	"status":    "ok",
	// 	"method":    c.Request.Method,
	// 	"operation": body.Operation,
	// 	"tags":      theTags,
	// 	"data":      body.Data,
	// })

}
