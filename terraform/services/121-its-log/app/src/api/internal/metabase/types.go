package metabase

import (
	"database/sql"
	"time"
)

type EventsRow struct {
	Id       int64
	Inserted time.Time
	KeyId    string
	Cluster  sql.NullString
	Tags     any
	Data     any
}
