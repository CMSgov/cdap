package types

type ETLPostBody struct {
	Name string `json:"name" binding:"required"`
	Kind string `json:"kind" binding:"required"`
	Body string `json:"body" binding:"required"`
	// Date string `json:"date" binding:"required"`
}

type SequencePostBody struct {
	Name string `json:"name" binding:"required"`
	Kind string `json:"kind" binding:"required"`
	Body []M    `json:"body" binding:"required"`
	// Date string           `json:"date" binding:"required"`
}
