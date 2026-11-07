package storage

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

type StoredSql int

const (
	Schema StoredSql = iota
	Endpoint
)

const SQL_NAMED_PARAM_SYMBOL = "$"

// var activeStorageConnections StorageMap = make(StorageMap, 0)

func DoesDBExist(pathArr []string) bool {
	dbPath := path.Join(pathArr...)

	_, err := os.Stat(dbPath)
	// If we don't get an error, the file exists.
	if err == nil {
		return true
	} else if errors.Is(err, os.ErrNotExist) {
		// If there is an error, we'll log and return.
		zap.L().Info("file does not exist",
			zap.String("filename", dbPath))
		return false
	} else {
		// Other errors could have occurred; for example,
		// there could be a disk error. Instead of handling everything,
		// we'll log the error, and indicate we cannot find the file.
		zap.L().Info("unknown error; file effectively does not exist",
			zap.Error(err))
		return false

	}
}

// Helper for the endpoints and other uses across the codebase
// This is the preferred entrypoint to the Storage API.
// func SetupDB(appId string, date string, kind StorageType) (*Storage, error) {
// 	s, err := NewStorage(appId)
// 	if err != nil {
// 		return nil, err
// 	}
// 	s.ILTime, err = types.StringToYMD(date)
// 	if err != nil {
// 		return nil, err
// 	}
// 	s.Kind = kind
// 	err = s.InitDB()
// 	if err != nil {
// 		log.Println("storage init error: " + err.Error())
// 		panic(err)
// 	}

// 	zap.L().Debug("SetupDB new storage created",
// 		zap.String("app_id", appId), zap.String("date", date))
// 	return s, nil
// }

// func NewStorage(appId string) (*Storage, error) {

// 	// Create DB
// 	s := &Storage{
// 		AppId: appId,
// 	}
// 	s.ILTime = types.NewILTimeToday()
// 	s.db = nil

// 	return s, nil
// }

// FIXME: Just pass `s` into this thing...
func ConstructDBFilenameAndPath(appId string, date string, kind StorageType) (string, []string) {
	// Compute filename based on date and app ID
	fname := fmt.Sprintf("%s_%s.duckdb", appId, date)
	var base string
	switch kind {
	case ArchiveStorage:
		base = viper.GetString("archive.path")
	case ConsolidatedStorage:
		base = viper.GetString("storage.path")
	case LiveStorage:
		base = viper.GetString("storage.path")
	}
	path := []string{base, fname}
	return fname, path
}

func asJson(params EmbedParamMap, trimmed string) ([]byte, error) {
	b, err := json.Marshal(params[trimmed])
	if err != nil {
		orig := fmt.Sprintf("%v", params[trimmed])
		return nil, fmt.Errorf("could not marshall JSON: %s", orig)
	}
	return b, nil
}
