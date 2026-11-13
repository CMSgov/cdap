package base

import (
	"fmt"
	"slices"

	"github.com/gin-gonic/gin"
)

func GetOrPanic(c *gin.Context, key string) string {
	v, exists := c.Get(key)
	if !exists {
		panic(fmt.Sprintf("could not get key from gin context: %s", key))
	}
	return v.(string)
}

func GetParamOrPanic(c *gin.Context, key string, allowed []string) string {
	if slices.Contains(allowed, c.Param(key)) {
		return c.Param(key)
	}
	panic(fmt.Sprintf("could not get url parameter: %s", key))
}
