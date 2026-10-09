package types

import (
	"database/sql"
)

type ETLPostBody struct {
	Name string `json:"name" binding:"required"`
	Kind string `json:"kind" binding:"required"`
	Body string `json:"body" binding:"required"`
	Date string `json:"date" binding:"required"`
}

type SequencePostBody struct {
	Name string           `json:"name" binding:"required"`
	Kind string           `json:"kind" binding:"required"`
	Body []map[string]any `json:"body" binding:"required"`
	Date string           `json:"date" binding:"required"`
}
type SummaryRow struct {
	ID        int64          `json:"id"`
	Inserted  int64          `json:"last_run"`
	Date      string         `json:"date"`
	KeyId     string         `json:"key_id"`
	Operation string         `json:"operation"`
	Tags      sql.NullString `json:"tags"`
	Value     sql.NullString `json:"value"`
	Count     float64        `json:"count"`
	Hash      sql.NullString `json:"hash"`
}
