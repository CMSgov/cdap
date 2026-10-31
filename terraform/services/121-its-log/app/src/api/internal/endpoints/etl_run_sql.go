package endpoints

import (
	"database/sql"
	"errors"

	etl "github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

func callWithParams(etlP *etl.RunEtlParams, theSql string) (*sql.Rows, error) {
	args, err := etlP.Storage.PrepareNamedArgs(etlP.EtlName, etlP.Payload)
	if err != nil {
		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
		return nil, err
	}

	etlP.Storage.Lock("callWithParams")
	etlRows, err := etlP.Storage.GetDB().Query(theSql, args...)
	etlP.Storage.Unlock("callWithParams")
	if err != nil {
		zap.L().Error("etl call failed", zap.Error(err))
		return nil, err
	}
	return etlRows, nil
}

func insertDefaultParams(etlP *etl.RunEtlParams) (*etl.RunEtlParams, error) {
	payload := etlP.Payload
	payload["key_id"] = etlP.KeyId
	payload["app_id"] = etlP.AppId
	// If the date is in the payload, and it is today or yesterday, convert it.
	if v, ok := payload["date"]; ok {
		date, err := types.SanitizeDate(v.(string))
		if err != nil {
			msg := "default parameter for date failed to parse"
			zap.L().Error(msg,
				zap.String("date", v.(string)))
			return nil, errors.New(msg)
		}
		payload["date"] = date
	} else {
		// If it was not in the payload, assume it is today.
		payload["date"] = types.NewILTimeToday().AsYYYYMMDD()
	}
	etlP.Payload = payload
	return etlP, nil
}

func etlRunSql(etlP *etl.RunEtlParams, etlRow storage.EtlRow, tx *sql.Tx) error {

	// Expect all ETLs to return rows that are shaped to the summary table.
	// operation, tags, value, count
	sqlRows, err := callWithParams(etlP, etlRow.Body)
	if err != nil {
		return err
	}
	defer sqlRows.Close()

	summaries := make([]etl.ItslogSummary, 0)
	row_count := 0
	for sqlRows.Next() {
		summary := etl.ItslogSummary{}
		err := sqlRows.Scan(&summary.Operation, &summary.Tags, &summary.Value, &summary.Count)
		if err != nil {
			zap.L().Info("error scanning row", zap.Int("row_count", row_count))
			return err
		}
		zap.L().Info("etl run sql",
			zap.String("op", summary.Operation),
			zap.String("tags", summary.Tags),
			zap.String("value", summary.Value),
			zap.Float64("count", summary.Count))
		row_count += 1
		summaries = append(summaries, summary)
	}

	return InsertSummaryRows("sql", etlP, summaries)

}
