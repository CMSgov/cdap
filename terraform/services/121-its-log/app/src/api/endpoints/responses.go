package endpoints

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func StatusOk(c *gin.Context, msg string) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"message": msg,
	})
}

func BadRequest(c *gin.Context, err error, msg string) {
	c.JSON(http.StatusBadRequest, gin.H{
		"status":  "error",
		"error":   err.Error(),
		"message": msg,
	})
}
