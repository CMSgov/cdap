package endpoints

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"time"

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
	localPath := path.Join(s.Path...)
	archiveFullPath := path.Join(viper.GetString("archive.path"), s.Filename)
	err = streamingCopy(localPath, archiveFullPath)
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

	// If it is not *today's* database, go ahead and delete it.

	// We cannot archive "today". Or, the current date.
	// This will break logging. So, we'll prevent it.

	go func() {
		// If we're trying to remove the database from *today*, then don't.
		if sanitizedDate == constants.TODAY || sanitizedDate == types.NewILTimeToday().AsYYYYMMDD() {
			return
		}

		consistencyTime := viper.GetInt("eventual.consistency.seconds")
		// On S3 Files, there is *eventual consistency*. We want to wait for that to settle, and
		// then we want to do a byte-by-byte comparison. If they match, we'll delete the local file.
		zap.L().Info("waiting before attempting event db removal",
			zap.Int("consistency_wait", consistencyTime))
		time.Sleep(time.Duration(consistencyTime) * time.Second)
		b, e := deepCompare(localPath, archiveFullPath)
		if b && e == nil {
			zap.L().Info("local and archive match; removing")
			os.Remove(localPath)
		} else {
			zap.L().Error("local and archive differ; not removing",
				zap.Bool("same", b), zap.Error(e))
		}
	}()

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

// From https://stackoverflow.com/questions/29505089/how-can-i-compare-two-files-in-golang
func deepCompare(file1, file2 string) (bool, error) {
	f1, err := os.Open(file1)
	if err != nil {
		zap.L().Info("cannot open source file for comparison", zap.String("filename", file1))
		return false, err
	}
	defer f1.Close()

	f2, err := os.Open(file2)
	if err != nil {
		zap.L().Info("cannot open destination file for comparison", zap.String("filename", file2))
		return false, err
	}
	defer f2.Close()

	// Fast check: If sizes don't match, files aren't identical
	stat1, err := f1.Stat()
	if err != nil {
		zap.L().Info("failed to stat source")
		return false, err
	}
	stat2, err := f2.Stat()
	if err != nil {
		zap.L().Info("failed to stat dest")
		return false, err
	}
	if stat1.Size() != stat2.Size() {
		zap.L().Info("file sizes differ",
			zap.Int64("source_stat", stat1.Size()),
			zap.Int64("dest_stat", stat2.Size()))
		return false, nil
	}

	// Compare chunks of 64KB
	const chunkSize = 64 * 1024
	b1 := make([]byte, chunkSize)
	b2 := make([]byte, chunkSize)
	chunkCount := 0
	for {
		n1, err1 := f1.Read(b1)
		n2, err2 := f2.Read(b2)

		if err1 != nil && err1 != io.EOF {
			zap.L().Info("end of source", zap.Int("chunk", chunkCount))
			return false, err1
		}
		if err2 != nil && err2 != io.EOF {
			zap.L().Info("end of dest", zap.Int("chunk", chunkCount))
			return false, err2
		}

		// Check if bytes read or content differs
		if n1 != n2 || !bytes.Equal(b1[:n1], b2[:n2]) {
			zap.L().Info("differ on chunk", zap.Int("chunk", chunkCount))
			return false, nil
		}

		// End of both files reached
		if err1 == io.EOF && err2 == io.EOF {
			break
		}
		chunkCount += 1
	}

	return true, nil
}
