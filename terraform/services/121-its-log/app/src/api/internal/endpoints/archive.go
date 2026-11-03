package endpoints

import (
	"bytes"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/etl"
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
	Date   string `json:"date"`
	Delete bool   `json:"delete"`
}

func Archive(c *gin.Context) {

	var body ETLArchive
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "message": fmt.Sprintf("should bind: %s", err.Error())})
		return
	}

	// First, sanitize the date.
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

	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)

	// Construct a path to the database, and make sure it exists.
	// We cannot archive a database that does not exist.
	_, dbpath := storage.ConstructDBFilenameAndPath(appId, sanitizedDate, storage.LiveStorage)
	if !storage.DoesDBExist(dbpath) {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "no db to archive",
			"date":    sanitizedDate,
		})
		return
	}

	// Open up the database, becuase it exists.
	s, err := SetupGinDB(c, storage.StorageConfig{
		AppId: appId,
		// We rarely use this parameter; only when we need to reach back
		// into the past. Here, we (mostly) want to archive databases that are
		// not *today*. Hence, we break the "model" that we only open
		// today's database to do work. Because this is not a typical DB operation.
		Date: sanitizedDate,
		Kind: storage.LiveStorage,
	})
	if err != nil {
		return
	}

	// The reason we opened it was to flush and close it.
	// This makes sure the WAL is written to the DB.
	s.Lock("Archive")
	s.Flush()
	s.Close()

	// Now, set up paths to the local DB and the archive we're about to create.
	localPath := path.Join(s.Path...)
	archiveFullPath := path.Join(viper.GetString("archive.path"), s.Filename)
	// Do a streaming copy.
	err = streamingCopy(localPath, archiveFullPath)
	if err != nil {
		zap.L().Error("archive copy error", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "could not copy archive",
			"date":    sanitizedDate,
		})
		// We closed the database
		// s.Unlock("Archive")
		return
	}

	// If we're trying to remove the database from *today*, then don't.
	if sanitizedDate == constants.TODAY || sanitizedDate == types.NewILTimeToday().AsYYYYMMDD() {
		s.Unlock("Archive")
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "cannot remove today's database",
			"date":    sanitizedDate,
		})
		return
	}

	// S3 Files has "eventual consistency". However, this does not apply to the process
	// doing the writing. So, our copy to an S3 Files mount will be available for comparison
	// *immediately*, because it is in *our* EFS caching layer.
	// consistencyTime := viper.GetInt("eventual.consistency.seconds")
	// zap.L().Info("waiting before attempting event db removal",
	// 	zap.Int("consistency_wait", consistencyTime))
	// time.Sleep(time.Duration(consistencyTime) * time.Second)

	// Do a deep compare, byte-by-byte, of the two files.
	// They should os.Stat() the same and have the exact same bytes in the same order.
	b, e := deepCompare(localPath, archiveFullPath)
	if b && e == nil {
		if body.Delete {
			// If they match, and the user told us to delete, remove the local file.
			zap.L().Info("local and archive match; removing")
			os.Remove(localPath)
		}
	} else {
		zap.L().Info("local and archive differ; not removing",
			zap.Bool("same", b), zap.Error(e))
	}

	// We closed the database
	// s.Unlock("Archive")
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
func deepCompare(src, dst string) (bool, error) {
	srcFile, err := os.Open(src)
	if err != nil {
		zap.L().Info("cannot open source file for comparison", zap.String("filename", src))
		return false, err
	}
	defer srcFile.Close()

	dstFile, err := os.Open(dst)
	if err != nil {
		zap.L().Info("cannot open destination file for comparison", zap.String("filename", dst))
		return false, err
	}
	defer dstFile.Close()

	// Fast check: If sizes don't match, files aren't identical
	srcStat, err := srcFile.Stat()
	if err != nil {
		zap.L().Info("failed to stat source")
		return false, err
	}
	dstStat, err := dstFile.Stat()
	if err != nil {
		zap.L().Info("failed to stat dest")
		return false, err
	}

	srcSize := srcStat.Size()
	dstSize := dstStat.Size()
	if srcSize != dstSize {
		zap.L().Info("file sizes differ",
			zap.Int64("source_stat", srcSize),
			zap.Int64("dest_stat", dstSize))
		return false, nil
	}

	// Compare chunks of 64KB
	const chunkSize = 64 * 1024
	srcBytes := make([]byte, chunkSize)
	dstBytes := make([]byte, chunkSize)
	chunkCount := 0
	for {
		srcBytesRead, srcErr := srcFile.Read(srcBytes)
		dstBytesRead, dstErr := dstFile.Read(dstBytes)

		if srcErr != nil && srcErr != io.EOF {
			zap.L().Info("end of source", zap.Int("chunk", chunkCount))
			return false, srcErr
		}
		if dstErr != nil && dstErr != io.EOF {
			zap.L().Info("end of dest", zap.Int("chunk", chunkCount))
			return false, dstErr
		}

		// Check if bytes read or content differs
		if srcBytesRead != dstBytesRead || !bytes.Equal(srcBytes[:srcBytesRead], dstBytes[:dstBytesRead]) {
			zap.L().Info("differ on chunk", zap.Int("chunk", chunkCount))
			return false, nil
		}

		// End of both files reached
		if srcErr == io.EOF && dstErr == io.EOF {
			break
		}
		chunkCount += 1
	}

	return true, nil
}

func GetArchiveDates(appId string) ([]string, error) {
	entries, err := os.ReadDir(viper.GetString("archive.path"))
	if err != nil {
		return nil, err
	}

	dates := make([]string, 0)
	re := regexp.MustCompile(`(\d{4}-\d{2}-\d{2})`)
	for _, entry := range entries {
		if strings.Contains(entry.Name(), appId) {
			name := entry.Name()
			if re.MatchString(name) {
				matches := re.FindStringSubmatch(name)
				dates = append(dates, matches[0])
			}
		}
	}
	return dates, nil
}

// ArchiveList
func ArchiveList(c *gin.Context) {
	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)
	dates, err := GetArchiveDates(appId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "error filtering archives",
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"method":  c.Request.Method,
		"entries": dates,
	})
}

func ArchiveConsolidate(c *gin.Context) {
	appId := base.GetOrPanic(c, constants.ITSLOG_APPID)
	keyId := base.GetOrPanic(c, constants.ITSLOG_KEYID)

	// Get a list of archives
	dates, err := GetArchiveDates(appId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"method":  c.Request.Method,
			"message": "error filtering archives",
		})
		return
	}

	to, err := SetupGinDB(c, storage.StorageConfig{
		AppId: appId,
		Kind:  storage.ConsolidatedStorage,
	})

	// Open an "archive" file
	// Copy the summary tables one-by-one
	for _, d := range dates {
		zap.L().Debug("dates",
			zap.Any("arch", to.Filename),
			zap.String("d", d),
		)
		from, err := SetupGinDB(c, storage.StorageConfig{
			AppId: appId,
			Date:  d,
			Kind:  storage.ArchiveStorage,
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"method":  c.Request.Method,
				"message": "could not access archive file",
			})
			return
		}

		from.KeyId = keyId
		err = consolidateFromTo(from, to)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"method":  c.Request.Method,
				"message": "could not consolidate archives",
				"error":   err.Error(),
			})
			to.Close()
			return
		}
	}
	to.Close()
}

func consolidateFromTo(from *storage.Storage, to *storage.Storage) error {
	zap.L().Debug("consolidating",
		zap.String("file", from.Filename),
		zap.Any("path", from.Path))
	rows, err := from.Query(storage.Endpoint, "get_all_summaries", storage.EmbedParamMap{})
	if err != nil {
		return err
	}
	defer rows.Close()

	summaries := make([]etl.ItslogSummary, 0)
	row_count := 0
	for rows.Next() {
		summary := etl.ItslogSummary{}
		err := rows.Scan(&summary.Operation, &summary.Tags, &summary.Data)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				zap.L().Info("consolidateFromTo returned zero rows")
				return nil
			} else {
				zap.L().Info("error scanning row", zap.Int("row_count", row_count))
				return err
			}
		}
		row_count += 1
		summaries = append(summaries, summary)
	}

	zap.L().Debug("read rows to consolidate", zap.Int("rows", row_count))

	err = InsertConsolidationRows(from, to, summaries)
	if err != nil {
		return err
	}
	return nil
}

func InsertConsolidationRows(from *storage.Storage, to *storage.Storage, summaries []etl.ItslogSummary) error {
	//
	// Now, write the new summar(y|ies) to the summary table.
	for _, summary := range summaries {
		payload := make(types.M, 0)
		payload["date"] = from.YYYYMMDD()
		payload["key_id"] = from.KeyId
		payload["operation"] = summary.Operation
		payload["tags"] = summary.Tags
		payload["data"] = summary.Data

		args, err := to.PrepareNamedArgs("insert_consolidated_row", payload)
		if err != nil {
			return err
		}

		to.Lock("InsertConsolidationRows")
		_, err = to.Endpoints.Exec("insert_consolidated_row", args)
		if err != nil {
			zap.L().Error("insertsummaryrows:insert_consolidated_row",
				zap.Any("payload", payload),
				zap.Error(err))
			to.Unlock("InsertConsolidationRows")
			return err
		}
		to.Unlock("InsertConsolidationRows")
	}

	return nil
}
