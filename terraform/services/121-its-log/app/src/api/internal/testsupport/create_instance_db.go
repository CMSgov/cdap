package testsupport

import (
	"fmt"
	"os"
	"testing"
	"uuid"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/csp"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/stretchr/testify/assert"
)

func CreateInstanceDbs(t *testing.T, app types.App, instanceCount int, eventsPerInstance int) {
	for range instanceCount {
		os.Setenv("ITSLOG_INSTANCE_ID", fmt.Sprintf("CT-%s", uuid.New().String()))
		e1 := CreateEvents(app, eventsPerInstance)
		inserted, err := csp.ManyEvents(e1)
		if err != nil {
			t.Error(err)
		}
		assert.Equal(t, int64(eventsPerInstance), inserted)
	}
}
