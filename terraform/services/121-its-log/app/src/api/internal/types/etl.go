package types

import "time"

type EtlRow struct {
	Name     string
	Language string
	Body     string
}

type EtlRunResult struct {
	Date      string
	Operation string
	Tags      any
	Data      any
}

type SummaryRow struct {
	ID        int64     `json:"id"`
	Inserted  time.Time `json:"inserted"`
	KeyId     string    `json:"key_id"`
	Date      string    `json:"date"`
	Operation string    `json:"operation"`
	Tags      any       `json:"tags"`
	Data      any       `json:"data"`
}

type EventRow struct {
	ID       int64     `json:"id"`
	Inserted time.Time `json:"inserted"`
	KeyId    string    `json:"key_id"`
	Cluster  string    `json:"cluster"`
	Tags     any       `json:"tags"`
	Data     any       `json:"data"`
}
