package base

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestGetOrPanicForcePanic(t *testing.T) {
	gin.SetMode(gin.TestMode)

	// A response recorder is sometimes desired for
	// capturing output.
	w := httptest.NewRecorder()

	// This is a test context and engine; we only need
	// the test context here.
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

	// A response recorder is sometimes desired for
	// capturing output.
	w := httptest.NewRecorder()

	// This is a test context and engine; we only need
	// the test context here.
	c, _ := gin.CreateTestContext(w)

	// Set some context
	c.Set("in-context", "value")

	// If the call does *not* panic, this will throw the error.
	defer func() {
		if r := recover(); r != nil {
			t.Error("code should not have panicked at the disco")
		}
	}()

	GetOrPanic(c, "in-context")
}
