package csp

import (
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func ManyEvents(s *storage.Storage, evt_buff []*types.Event) (int64, error) {
	counter := int64(0)

	// This could/should become an appender in DuckDB.
	// https://duckdb.org/docs/current/data/appender
	// Doing individual commits without a transaction is the slowest
	// way to do this in DuckDB. Appenders are much better, both for
	// performance and safety.
	for _, e := range evt_buff {
		if e != nil {

			s.GetDB().Prepare(s.Endpoints.Files["log_event"])
			_, err := s.ExecNoLock(storage.Endpoint,
				"log_event",
				storage.EmbedParamMap{
					"inserted": e.Timestamp,
					"key_id":   e.KeyId,
					"cluster":  e.Cluster,
					"tags":     e.TagString,
					"data":     e.Data,
				},
			)
			if err != nil {
				zap.L().Error("error storing event", zap.Error(err))
				return -1, err
			}
			counter += 1
		}
	}

	zap.L().Debug("ManyEvents", zap.Int64("counter", counter))
	return counter, nil
}
