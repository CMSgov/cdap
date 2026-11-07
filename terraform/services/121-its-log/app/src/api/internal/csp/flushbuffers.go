package csp

import (
	"time"

	_ "github.com/duckdb/duckdb-go/v2"
	"go.uber.org/zap"
)

// For use in infinite contexts
func FlushBuffers(ch_flush_in <-chan EventBuffer) {
	for {
		FlushBuffersOnce(ch_flush_in)
	}
}

func FlushBuffersOnce(ch_flush_in <-chan EventBuffer) {
	eventBuffer := <-ch_flush_in
	// org := organizeEvents(eventBuffer)
	org := make(map[string][]*Event, 0)
	// Organize the events
	if eventBuffer.EventBufferLength <= 0 {
		zap.L().Info("no events in buffer")
		return
	}

	for _, evt := range eventBuffer.Events {
		if evt != nil {
			if _, exists := org[evt.AppId]; !exists {
				org[evt.AppId] = make([]*Event, 0)
			}
			org[evt.AppId] = append(org[evt.AppId], evt)
		}
	}
	// Flush them
	for _, events := range org {
		start := time.Now() // Record the start time
		inserted, err := ManyEvents(events)
		end := time.Now()
		if err != nil {
			zap.L().Info("failed to flush many events",
				zap.Int64("inserted", inserted),
				zap.Error(err))
		}
		zap.L().Info("appended events",
			zap.Int64("count", inserted),
			zap.Int64("milliseconds", time.Duration(end.Sub(start)).Milliseconds()))
	}

}
