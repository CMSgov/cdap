package csp

import (
	"time"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/storage"
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

// For use in infinite contexts
func FlushBuffers(ch_flush_in <-chan types.EventBuffer) {
	for {
		FlushBuffersOnce(ch_flush_in)
	}
}

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
			formatted_date := d.Format("2006-01-02")

			if _, ok := org[evt.AppId]; !ok {
				// If we have not seen this app before, we have to initialize it
				org[evt.AppId] = make(map[string][]*types.Event)
			}

			// Now, have we seen this date before from that app?
			if _, ok := org[evt.AppId]; !ok {
				org[evt.AppId][formatted_date] = make([]*types.Event, 0)
			}

			// We're ready; append the event
			org[evt.AppId][formatted_date] = append(org[evt.AppId][formatted_date], evt)

			// DEBUG LOG
			// log.Printf("organizeEvents: %s[%s] <- %s", evt.AppId, formatted_date, evt)
		}
	}

	return org

}

func FlushBuffersOnce(ch_flush_in <-chan types.EventBuffer) {
	eventBuffer := <-ch_flush_in
	org := organizeEvents(eventBuffer)

	for appId, dateMap := range org {

		for formattedDate, events := range dateMap {

			zap.L().Debug("FlushBuffersOnce dateMap",
				zap.String("formatted_date", formattedDate),
				zap.Int("len(events)", len(events)))

			s, err := storage.SetupDB(appId, formattedDate)

			if err != nil {
				zap.L().Fatal("could not setup DB in flushbuffers",
					zap.String("appId", appId), zap.String("date", formattedDate),
					zap.Error(err))
			}

			s.Lock("FlushBuffersOnce")
			s.GetAppender("itslog_events")
			start := time.Now() // Record the start time
			inserted, err := ManyEvents(s, events)
			if err != nil {
				zap.L().Error("error in event insertion", zap.Error(err))
			}
			s.FlushAppender()
			s.CloseAppender()
			s.Unlock("FlushBuffersOnce")

			duration := time.Since(start)

			if err != nil {
				// FIXME: really, this should percolate up to a 5xx error
				// going back to the client. But, there's no direct communication back to
				// the client at this point, because we buffered the event(s), and then
				// flushed the buffer. This may have to just be a log that we look for.
				zap.L().Error("failed to write event buffer; lost events",
					zap.Int("events_lost", len(events)),
					zap.Error(err))
			} else {
				zap.L().Info("appended events",
					zap.Int64("count", inserted),
					zap.Int64("milliseconds", duration.Milliseconds()))
			}

			// Should we close here?
			// NO. We leave sessions open, and cache them in a map.
			// We assume we will only have so many apps open.
			// This *might* be an issue as we roll day-to-day.
			// That could be handled down in the Storage abstraction.
			// s.Close()
		}
	}

}

func ManyEvents(s *storage.Storage, evt_buff []*types.Event) (int64, error) {
	counter := int64(0)

	max_id, err := s.GetMaxId("get_max_event_id", storage.EmbedParamMap{})
	if err != nil {
		return -1, err
	}

	// This could/should become an appender in DuckDB.
	// https://duckdb.org/docs/current/data/appender
	// Doing individual commits without a transaction is the slowest
	// way to do this in DuckDB. Appenders are much better, both for
	// performance and safety.
	for _, e := range evt_buff {
		if e != nil {
			max_id += 1
			err := s.AppendRow(max_id, e.Timestamp.Unix(), e.KeyId, e.Cluster, e.TagString, e.Value)
			if err != nil {
				zap.L().Error("error storing event", zap.Error(err))
				return -1, err
			}
			counter += 1
		}
	}

	return counter, nil
}
