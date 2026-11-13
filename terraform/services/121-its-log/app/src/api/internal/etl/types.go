package etl

import "github.com/navapbc/its-log/internal/types"

type EtlParam struct {
	Name  string `json:"name" binding:"required"`
	Value any    `json:"value" binding:"required"`
	Type  string `json:"type" binding:"required,oneof=int float text array object"`
}
type RunEtlBody struct {
	App         types.App
	Kind        string     `json:"kind" binding:"required,oneof=daily monthly yearly full"`
	Destination string     `json:"destination" binding:"required,oneof=summary csv"`
	Name        string     `json:"name" binding:"required"`
	YMD         string     `json:"ymd" binding:"omitempty,validateYMD"`
	Year        int        `json:"year" binding:"omitempty,gte=2000"`
	Month       int        `json:"month" binding:"omitempty,gte=1,lte=12"`
	Params      []EtlParam `json:"params" binding:"omitempty"`
}
