package csp

import (
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func ManyEvents(events []*types.Event) (int64, error) {
	counter := int64(0)
	var app types.App
	if len(events) > 0 {
		app = types.App{
			AppId: events[0].AppId,
			KeyId: events[0].KeyId,
		}
	} else {
		return 0, nil
	}
	id, err := metabase.NewInstanceDatabase(&metabase.InstanceParams{
		App:      app,
		YYYYMMDD: types.NewYYYYMMDD().String(),
	})
	if err != nil {
		zap.L().Error("could not create instance database")
		return -1, err
	}
	err = id.Open(metabase.OpenExistingOrCreateNew)
	if err != nil {
		zap.L().Error("could not open instance database")
		return -1, err
	}

	id.Lock("ManyEvents")
	defer func() {
		id.Unlock("ManyEvents")
		id.Flush()
		id.Close()
	}()

	for _, e := range events {
		if e != nil {
			_, err := metabase.ExecNoLock(id,
				embedfs.EmbeddedEndpoints.GetOrPanic("log_event"),
				types.M{
					"inserted": e.Timestamp,
					"key_id":   e.KeyId,
					"cluster":  e.Cluster,
					"tags":     e.Tags,
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
