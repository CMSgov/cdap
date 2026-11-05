package csp

import (
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// Using a nested set of maps, we end up with a structure
// that looks roughly like the following:
//
// app1
//
//	|
//	| - 2026-01-01 <- [ e1, e3 ]
//	| - 2026-01-02 <- [ e2, e4, e5 ]
//
// app2
//
//	\
//	 2026-01-01 <- [ e6 ]
type BufferTree map[string]map[string][]*types.Event

// We could be getting things from any number of apps at any given time.
// Therefore, the buffer needs to be organized for writing.
// It is a multi-level hash.
// org[appId][date] = []events
func organizeEvents(eventBuffer types.EventBuffer) BufferTree {
	org := make(BufferTree)

	for _, evt := range eventBuffer.Events {
		// For each event
		if evt != nil {
			// If it isn't nil, lets grab the date from the event.
			// From test endpoints, this can vary widely.
			d := evt.Timestamp
			formattedDate := d.Format("2006-01-02")

			if _, ok := org[evt.AppId]; !ok {
				// If we have not seen this app before, we have to initialize it
				org[evt.AppId] = make(map[string][]*types.Event)
			}

			// Now, have we seen this date before from that app?
			if _, ok := org[evt.AppId]; !ok {
				org[evt.AppId][formattedDate] = make([]*types.Event, 0)
			}

			// We're ready; append the event
			org[evt.AppId][formattedDate] = append(org[evt.AppId][formattedDate], evt)

			// DEBUG LOG
			zap.L().Debug("organize events",
				zap.String("appId", evt.AppId),
				zap.String("date", formattedDate),
			)
		}
	}

	return org

}
