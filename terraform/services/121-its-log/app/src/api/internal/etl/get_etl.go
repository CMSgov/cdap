package etl

import (
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
	var summaries []types.EtlRunResult
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
				{Name: "date", Value: summary.Date, Type: embedfs.EmbeddedString},
				{Name: "key_id", Value: etlb.App.KeyId, Type: embedfs.EmbeddedString},
				{Name: "operation", Value: summary.Operation, Type: embedfs.EmbeddedString},
				{Name: "tags", Value: summary.Tags, Type: embedfs.EmbeddedJson},
				{Name: "data", Value: summary.Data, Type: embedfs.EmbeddedJson},
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

func RunAndReturnRows(m *metabase.Metabase, etlb RunEtlBody, row types.EtlRow) ([]types.EtlRunResult, error) {
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

	erunres := make([]types.EtlRunResult, 0)
	switch row.Language {
	case "sql":
		rows, err := metabase.Query(m, row.Body, params)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var res types.EtlRunResult
			serr := rows.Scan(
				&res.Date,
				&res.Operation,
				&res.Tags,
				&res.Data,
			)
			if serr != nil {
				return nil, serr
			}
			if types.IsValidYYYYMMDD(res.Date) != nil {
				return nil, fmt.Errorf("invalid date returned from sql etl: ['%s']", res.Date)
			}
			erunres = append(erunres, res)
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
