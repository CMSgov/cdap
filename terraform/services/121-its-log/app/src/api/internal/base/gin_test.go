package base

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestGetOrPanicForcePanic(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	// If the call does *not* panic, this will throw the error.
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic as expected")
		}
	}()
	GetOrPanic(c, "not-in-context")
}

func TestGetOrPanicNoPanic(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	// Set some context
	c.Set("in-context", "value")
	// If the panics, this will throw the error.
	defer func() {
		if r := recover(); r != nil {
			t.Error("code should not have panicked at the disco")
		}
	}()
	GetOrPanic(c, "in-context")
}
