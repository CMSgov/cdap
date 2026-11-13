package etl

import (
	"errors"

	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/embedfs"
	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func RunAndInsertEtl(m *metabase.Metabase, etlb RunEtlBody) ([]types.EtlRunResult, error) {
	var etlRow types.EtlRow
	row := metabase.QueryRow(m,
		embedfs.EmbeddedEndpoints.GetOrPanic("read_etl"),
		[]embedfs.EmbeddedParam{
			{Name: "name", Value: etlb.Name, Type: embedfs.EmbeddedString},
		})
	if row.Err() != nil {
		return nil, errors.New("etl query error")
	}
	scanErr := row.Scan(&etlRow.Name, &etlRow.Language, &etlRow.Body)
	if scanErr != nil {
		return nil, errors.New("could not scan etl row")
	}

	// Now, we have the ETL. Run it.
	var results []types.EtlRunResult
	switch etlRow.Language {
	case "sql":
		summaries, err := RunAndReturnRows(m, etlb, etlRow)
		if err != nil {
			return nil, err
		}
		zap.L().Info("run and return", zap.Any("summaries", summaries))
	case "starlark":
		// pass
	}

	return results, nil

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
func RunAndReturnRows(m *metabase.Metabase, etlb RunEtlBody, row types.EtlRow) ([]types.SummaryRow, error) {
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
	rows, err := metabase.Query(m, row.Body, params)
	if err != nil {
		return nil, err
	}
	zap.L().Info("query", zap.Any("rows", rows))
	return nil, nil
}

func RunAndWriteEtl(m *metabase.Metabase, name string) ([]types.EtlRunResult, error) {
	var etlRow types.EtlRow
	row := metabase.QueryRow(m,
		embedfs.EmbeddedEndpoints.GetOrPanic("read_etl"),
		[]embedfs.EmbeddedParam{
			{Name: "name", Value: name, Type: embedfs.EmbeddedString},
		})
	if row.Err() != nil {
		return nil, errors.New("etl query error")
	}
	scanErr := row.Scan(&etlRow.Name, &etlRow.Language, &etlRow.Body)
	if scanErr != nil {
		return nil, errors.New("could not scan etl row")
	}

	// Now, we have the ETL. Run it.
	var results []types.EtlRunResult
	switch etlRow.Language {
	case "sql":
		// pass
	case "starlark":
		// pass
	}

	return results, nil

}
