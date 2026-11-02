package types

import (
	"database/sql"
	"time"
)

type Event struct {
	Timestamp time.Time
	AppId     string
	KeyId     string
	Cluster   string   `json:"cluster"`
	Tags      []string `json:"tags" binding:"required"`
	TagString string
	Data      M      `json:"data" binding:"required"`
	Date      string `json:"date"`
}

type EventRow struct {
	ID       int64
	Inserted time.Time
	KeyId    string
	Cluster  sql.NullString
	Tags     string
	Data     M
}
