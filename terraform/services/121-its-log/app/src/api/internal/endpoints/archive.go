package endpoints

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

// An archive call moves a database to the archive path.
// Lock
// Checkpoint
// Close
// Move

type ETLArchive struct {
	Date string `json:"date"`
}

func Archive(c *gin.Context) {

	var body ETLArchive
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}
	sanitizedDate, err := types.SanitizeDate(body.Date)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "invalid date",
			"date":    body.Date,
		})
		return
	}

	// We cannot archive "today". Or, the current date.
	// This will break logging. So, we'll prevent it.
	if sanitizedDate == constants.TODAY || sanitizedDate == types.NewILTimeToday().AsYYYYMMDD() {
		msg := "cannot archive the current log database"
		zap.L().Error(msg, zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": msg,
			"date":    sanitizedDate,
		})
		return
	}

	appId := base.GetOrPanic(c, "AppId")
	_, dbpath := storage.ConstructDBFilenameAndPath(appId, sanitizedDate)
	if !storage.DoesDBExist(dbpath) {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "no db to archive",
			"date":    sanitizedDate,
		})
		return
	}

	s, err := storage.SetupDB(appId, sanitizedDate)
	if err != nil {
		zap.L().Error("archive setup error", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not set up archive db",
			"date":    sanitizedDate,
		})
		return
	}

	s.Lock("Archive")
	defer s.Unlock("Archive")

	s.Flush()
	s.Close()
	archiveFullPath := path.Join(viper.GetString("archive.path"), s.Filename)
	err = streamingCopy(path.Join(s.Path...), archiveFullPath)
	if err != nil {
		zap.L().Error("archive copy error", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not copy archive",
			"date":    sanitizedDate,
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status": "ok",
		"method": c.Request.Method,
		"date":   sanitizedDate,
	})
}

func streamingCopy(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer sourceFile.Close()

	destinationFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer destinationFile.Close()

	_, err = io.Copy(destinationFile, sourceFile)
	if err != nil {
		return fmt.Errorf("failed to copy data: %w", err)
	}

	err = destinationFile.Sync()
	if err != nil {
		return fmt.Errorf("failed to sync destination file: %w", err)
	}

	return nil
}
