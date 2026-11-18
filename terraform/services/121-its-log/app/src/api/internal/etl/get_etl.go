package etl

import (
	"database/sql"
	"errors"
	"fmt"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/embedfs"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/types"
	"go.uber.org/zap"
)

func RunAndInsertEtl(m *metabase.Metabase, etlb RunEtlBody) (int, error) {
	var er types.EtlRow
	row := metabase.QueryRow(m,
		embedfs.EmbeddedEndpoints.GetOrPanic("read_etl"),
		[]embedfs.EmbeddedParam{
			{Name: "name", Value: etlb.Name, Type: embedfs.EmbeddedString},
		})
	if row.Err() != nil {
		return -1, fmt.Errorf("read_etl: %s", row.Err().Error())
	}
	scanErr := row.Scan(&er.Name, &er.Language, &er.Body)
	if scanErr != nil {
		return -1, scanErr
	}

	// Now, we have the ETL. Run it.
	var summaries []types.M
	var err error
	summaries, err = RunAndReturnRows(m, etlb, er)
	if err != nil {
		return -1, err
	}

	// Write the rows back to the summary table.
	for _, summary := range summaries {
		_, err := metabase.Exec(m,
			embedfs.EmbeddedEndpoints.GetOrPanic("create_summary"),
			[]embedfs.EmbeddedParam{
				{Name: "date", Value: summary["date"], Type: embedfs.EmbeddedString},
				{Name: "key_id", Value: etlb.App.KeyId, Type: embedfs.EmbeddedString},
				{Name: "operation", Value: summary["operation"], Type: embedfs.EmbeddedString},
				{Name: "tags", Value: summary["tags"], Type: embedfs.EmbeddedJson},
				{Name: "data", Value: summary["data"], Type: embedfs.EmbeddedJson},
			})
		if err != nil {
			return -1, err
		}
	}

	return len(summaries), nil

}

func userTypeToInternalType(t string) embedfs.EmbeddedParamType {
	switch t {
	case "int":
		return embedfs.EmbeddedInt64
	case "float":
		panic("float not handled")
	case "text":
		return embedfs.EmbeddedString
	case "array":
		return embedfs.EmbeddedJson
	case "object":
		return embedfs.EmbeddedJson
	default:
		panic("unknown type from user; should not get here")
	}
}

func RunAndReturnRows(m *metabase.Metabase, etlb RunEtlBody, row types.EtlRow) ([]types.M, error) {
	// Run the ETL
	// Add another "no insert, delete, update" check here, for thoroughness
	if !base.CheckNotAllowed(row.Body) {
		return nil, errors.New("sql contains insert/delete/update")
	}

	var params = make([]embedfs.EmbeddedParam, 0)
	// The user passed in params. We need them in a different data structure.
	for _, p := range etlb.Params {
		params = append(params, embedfs.EmbeddedParam{
			Name:  p.Name,
			Value: p.Value,
			Type:  userTypeToInternalType(p.Type),
		})
	}

	var erunres []types.M
	switch row.Language {
	case "sql":
		rows, err := metabase.Query(m, row.Body, params)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		erunres, err = scanRowsToMaps(rows)
		if err != nil {
			zap.L().Info("error scanning rows to map", zap.Error(err))
			return nil, err
		}
	case "starlark":
		var err error
		erunres, err = RunStarlark(m, etlb, row)
		if err != nil {
			return nil, err
		}
		zap.L().Info("starlark", zap.Any("result", erunres))
	}

	return erunres, nil
}

// From
// https://kylewbanks.com/blog/query-result-to-map-in-golang
func scanRowsToMaps(rows *sql.Rows) ([]types.M, error) {
	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}

	var results []types.M

	for rows.Next() {
		values := make([]any, len(cols))
		valuePtrs := make([]any, len(cols))
		for i := range cols {
			valuePtrs[i] = &values[i]
		}
		if err := rows.Scan(valuePtrs...); err != nil {
			return nil, err
		}
		rowMap := make(types.M, len(cols))
		for i, colName := range cols {
			val := values[i]
			if b, ok := val.([]byte); ok {
				rowMap[colName] = string(b)
			} else {
				rowMap[colName] = val
			}
		}
		results = append(results, rowMap)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return results, nil
}
