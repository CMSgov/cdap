package metabase

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// Consumes the name of embedded SQL and a parameter map.
// Finds the named params in the SQL (which must begin with $_)
// and looks up the name in the map, returning a list of sql.NamedArgs
// matching the variables needed to execute the SQL
func PrepareNamedArgs(sql string, params embedfs.EmbedParamMap) ([]any, error) {
	// Look for the named params expected in the SQL
	named, err := generateNamedArgs(sql, params)
	if err != nil {
		return nil, err
	}
	return named, nil
}

func generateNamedArgs(theSql string, params embedfs.EmbedParamMap) ([]any, error) {
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
			case nil:
				params[trimmed] = sql.NullString{String: "", Valid: false}
			case int:
				params[trimmed] = strconv.Itoa(params[trimmed].(int))
			case int64:
				params[trimmed] = strconv.FormatInt(params[trimmed].(int64), 10)
			case float64:
				params[trimmed] = strconv.FormatFloat(params[trimmed].(float64), 'f', -1, 64)
			case string:
				params[trimmed] = params[trimmed]
			case *string:
				if params[trimmed] == nil {
					params[trimmed] = sql.NullString{String: "", Valid: false}
				} else {
					params[trimmed] = params[trimmed]
				}
			case []string:
				b, _ := json.Marshal(params[trimmed])
				params[trimmed] = b
			case types.M:
				b, err := asJson(params, trimmed)
				if err != nil {
					return nil, err
				}
				params[trimmed] = string(b)
			case []any:
				b, err := asJson(params, trimmed)
				if err != nil {
					return nil, err
				}
				params[trimmed] = string(b)
			case time.Time:
				params[trimmed] = params[trimmed].(time.Time)
			case sql.NullString:
				ns := params[trimmed].(sql.NullString)
				if ns.Valid {
					params[trimmed] = ns.String
				} else {
					params[trimmed] = nil
				}
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

func asJson(params embedfs.EmbedParamMap, trimmed string) ([]byte, error) {
	b, err := json.Marshal(params[trimmed])
	if err != nil {
		orig := fmt.Sprintf("%v", params[trimmed])
		return nil, fmt.Errorf("could not marshall JSON: %s", orig)
	}
	return b, nil
}
