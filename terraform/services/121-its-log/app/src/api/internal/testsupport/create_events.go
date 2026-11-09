package testsupport

import (
	"github.com/navapbc/its-log/internal/types"
)

func CreateEvents(app types.App, n int) []*types.Event {
	events := make([]*types.Event, 0)

	for range n {
		e := types.RandomEvent(app)
		events = append(events, &e)
	}
	return events
}
