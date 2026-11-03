package types

type SummaryPostBody struct {
	// Date      string   `json:"date" binding:"required"`
	Operation string   `json:"operation" binding:"required"`
	Tags      []string `json:"tags"`
	Data      any      `json:"data" binding:"required"`
}
