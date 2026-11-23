package metabase

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"maps"
	"regexp"
	"slices"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/embedfs"
)

// Consumes the name of embedded SQL and a parameter map.
// Finds the named params in the SQL (which must begin with $_)
// and looks up the name in the map, returning a list of sql.NamedArgs
// matching the variables needed to execute the SQL
func PrepareNamedArgs(theSql string, params []embedfs.EmbeddedParam) ([]any, error) {
	// Coerce the go types to the desired targets.
	coerced := make([]embedfs.EmbeddedParam, 0)
	for _, param := range params {
		// We have intended types that we want values coerced to.
		switch param.Type {
		case embedfs.EmbeddedInt:
			coerced = append(coerced, param)
		case embedfs.EmbeddedInt64:
			coerced = append(coerced, param)
		case embedfs.EmbeddedString:
			coerced = append(coerced, embedfs.EmbeddedParam{
				Name:  param.Name,
				Value: param.Value,
				Type:  param.Type,
			})
		case embedfs.EmbeddedJson:
			v, err := asJson(param.Value)
			if err != nil {
				return nil, err
			}
			coerced = append(coerced, embedfs.EmbeddedParam{
				Name:  param.Name,
				Value: v,
				Type:  param.Type,
			})
		case embedfs.EmbeddedRaw:
			// Pass it through
			coerced = append(coerced, embedfs.EmbeddedParam{
				Name:  param.Name,
				Value: param.Value,
				Type:  param.Type,
			})
		case embedfs.EmbeddedTime:
			// Pass it through
			coerced = append(coerced, embedfs.EmbeddedParam{
				Name:  param.Name,
				Value: param.Value,
				Type:  param.Type,
			})
		default:
			panic("unhandled named arg coersion type")
		}
	}

	named := make([]any, 0)
	present := namesPresent(theSql)
	for _, param := range coerced {
		if slices.Contains(present, param.Name) {
			named = append(named, sql.Named(param.Name, param.Value))
		}
	}
	return named, nil
}

func namesPresent(theSql string) []string {
	all_matches := make(map[string]any, 0)
	re := regexp.MustCompile(`\$(?P<tag>[a-zA-Z0-9_]+)`)
	match_pairs := re.FindAllStringSubmatch(theSql, -1)
	// Comes back as a list of pairs, ["$burt", "burt"], ["$ernie", "ernie"]
	for _, pair := range match_pairs {
		all_matches[pair[1]] = true
	}
	// What if we use getvariable?
	re = regexp.MustCompile(`getvariable\('(?P<tag>[a-zA-Z0-9_]+)'\)`)
	var_pairs := re.FindAllStringSubmatch(theSql, -1)
	for _, pair := range var_pairs {
		all_matches[pair[1]] = true
	}

	// Uniquify; we want each match only once.
	matches := slices.Collect(maps.Keys(all_matches))
	return matches
}

func asJson(v any) ([]byte, error) {
	b, err := json.Marshal(v)
	if err != nil {
		orig := fmt.Sprintf("%v", v)
		return nil, fmt.Errorf("could not marshall JSON: %s", orig)
	}
	return b, nil
}
