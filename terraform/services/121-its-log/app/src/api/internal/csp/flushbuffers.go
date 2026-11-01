package csp

import (
	"time"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// For use in infinite contexts
func FlushBuffers(ch_flush_in <-chan types.EventBuffer) {
	for {
		FlushBuffersOnce(ch_flush_in)
	}
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
			start := time.Now() // Record the start time
			inserted, err := ManyEvents(s, events)
			if err != nil {
				zap.L().Error("failed to write event buffer; lost events",
					zap.Int("events_lost", len(events)),
					zap.Error(err))
				s.Close()
				s.Unlock("FlushBuffersOnce")
				break
			} else {
				duration := time.Since(start)
				s.Unlock("FlushBuffersOnce")
				s.Close()
				zap.L().Info("appended events",
					zap.Int64("count", inserted),
					zap.Int64("milliseconds", duration.Milliseconds()))
			}
		}
	}
}
