package endpoints

import (
	"sort"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/constants"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/gin-gonic/gin"
)

func LogCreate(ch_evt_out chan<- *types.Event) func(c *gin.Context) {
	return func(c *gin.Context) {
		var evt types.Event
		if err := c.ShouldBindJSON(&evt); err != nil {
			BadRequest(c, err, "invalid json")
			return
		}

		evt.AppId = base.GetOrPanic(c, constants.ITSLOG_APPID)
		evt.KeyId = base.GetOrPanic(c, constants.ITSLOG_KEYID)

		// The tags field comes in as a JSON array. It needs to become
		// a sorted, dot-separated string.
		sort.Strings(evt.Tags)
		// evt.TagString = strings.Join(evt.Tags, ".")

		// Send the event to the Enqueue-er
		ch_evt_out <- &evt

		// Everything worked.
		StatusOk(c, "event logged")
	}
}
