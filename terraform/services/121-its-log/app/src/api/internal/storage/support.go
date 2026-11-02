package storage

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"regexp"
	"slices"
	"strconv"
	"strings"

	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/navapbc/its-log/internal/types"
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
func SetupDB(appId string, date string) (*Storage, error) {
	s, err := NewStorage(appId)
	if err != nil {
		return nil, err
	}
	s.ILTime, err = types.StringToYMD(date)
	if err != nil {
		return nil, err
	}

	err = s.InitDB()
	if err != nil {
		log.Println("storage init error: " + err.Error())
		panic(err)
	}

	zap.L().Debug("SetupDB new storage created",
		zap.String("app_id", appId), zap.String("date", date))
	return s, nil
}

func NewStorage(appId string) (*Storage, error) {

	// Create DB
	s := &Storage{
		AppId: appId,
	}
	s.ILTime = types.NewILTimeToday()
	s.db = nil

	return s, nil
}

func ConstructDBFilenameAndPath(appId string, date string) (string, []string) {
	// Compute filename based on date and app ID
	fname := fmt.Sprintf("%s_%s.duckdb", appId, date)
	path := []string{viper.GetString("storage.path"), fname}
	return fname, path
}

func GenerateNamedArgs(theSql string, params EmbedParamMap) ([]any, error) {
	// We now are going to figure out which named params are present in the SQL.
	// That way, we only create named args for things that are present.
	// The SQL engine does not like when you pass named paramters that do not exist in the SQL.
	// E.g. we cannot provide more names than exist.
	re := regexp.MustCompile(`\` + SQL_NAMED_PARAM_SYMBOL + `([a-zA-Z0-9_]+)`)
	matches := re.FindAllString(theSql, -1)

	// Uniquify; we want each match only once.
	slices.Sort(matches)
	matches = slices.Compact(matches)

	// And, check everything we found in the SQL is in the params
	named := make([]any, 0)

	for _, arg := range matches {
		trimmed := strings.Replace(arg, "$", "", 1)
		if _, ok := params[trimmed]; !ok {
			zap.L().Error("found in SQL but not in params",
				zap.String("trimmed", trimmed))
			return nil, fmt.Errorf("%s found in SQL but not in params", trimmed)
		} else {
			// If we are dealing with a JSON map in the values,
			// it needs to be marshalled to a byte array.
			switch params[trimmed].(type) {
			case int:
				params[trimmed] = strconv.Itoa(params[trimmed].(int))
			case int64:
				params[trimmed] = strconv.FormatInt(params[trimmed].(int64), 10)
			case float64:
				params[trimmed] = strconv.FormatFloat(params[trimmed].(float64), 'f', -1, 64)
			case string:
				params[trimmed] = params[trimmed]
			case types.M:
				b, err := json.Marshal(params[trimmed])
				if err != nil {
					orig := fmt.Sprintf("%v", params[trimmed])
					return nil, fmt.Errorf("could not marshall JSON: %s", orig)
				}
				params[trimmed] = string(b)
			default:
				zap.L().Error("unable to generate named arg",
					zap.String("key", trimmed),
					zap.Any("value", params[trimmed]),
					zap.String("type", fmt.Sprintf("%T", params[trimmed])))
			}
			named = append(named, sql.Named(trimmed, params[trimmed]))
		}
	}

	return named, nil
}
