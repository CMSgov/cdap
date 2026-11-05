package endpoints

import (
	"database/sql"
	"errors"
	"fmt"

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

	lockString := fmt.Sprintf("callWithParams:%s", etlP.EtlName)
	etlP.Storage.Lock(lockString)
	etlRows, err := etlP.Storage.GetDB().Query(theSql, args...)
	etlP.Storage.Unlock(lockString)
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

func etlRunSql(etlP *etl.RunEtlParams, etlRow storage.EtlRow) error {

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
		err := sqlRows.Scan(&summary.Operation, &summary.Tags, &summary.Data) // &summary.Value, &summary.Count)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				zap.L().Info("etl returned zero rows", zap.String("name", etlP.EtlName))
				return nil
			} else {
				zap.L().Info("error scanning row", zap.Int("row_count", row_count))
				return err
			}
		}
		zap.L().Info("etl run sql",
			zap.String("operation", summary.Operation),
			zap.String("tags", summary.Tags),
			zap.String("data", fmt.Sprintf("%v", summary.Data)),
		)
		row_count += 1
		summaries = append(summaries, summary)
	}

	etlP.DeleteBeforeInsert = true
	return InsertSummaryRows("sql", etlP, summaries)

}
