package endpoints

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/navapbc/its-log/internal/etl"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	starjson "go.starlark.net/lib/json"
	starmath "go.starlark.net/lib/math"
	startime "go.starlark.net/lib/time"

	"go.starlark.net/starlark"
	"go.starlark.net/syntax"
	"go.uber.org/zap"
)

// -----------
// Running Starlark ETLs

func queryFun(etlP *etl.RunEtlParams) func(_ *starlark.Thread, _ *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	return func(_ *starlark.Thread, _ *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
		var queryTable string
		var queryString string
		if err := starlark.UnpackArgs(
			"config", args, kwargs,
			"table", &queryTable, "query", &queryString,
		); err != nil {
			return starlark.None, fmt.Errorf("config: %s", err)
		}

		paramMap := storage.EmbedParamMap{
			"key_id": etlP.KeyId,
			"app_id": etlP.AppId,
			"date":   etlP.Storage.YYYYMMDD(),
		}
		sqlArgs, err := storage.GenerateNamedArgs(queryString, paramMap)

		// An SQL step will read from and write to the DB.
		// Lock and release around this action.
		lockMsg := "starlark:queryfun:" + etlP.EtlName
		etlP.Storage.Lock(lockMsg)
		rows, err := etlP.Storage.GetDB().Query(queryString, sqlArgs...)
		etlP.Storage.Unlock(lockMsg)
		if err != nil {
			return starlark.None, err
		}
		if rows.Err() != nil {
			return starlark.None, rows.Err()
		}

		resultList := starlark.NewList([]starlark.Value{})
		for rows.Next() {
			switch queryTable {
			case "events":
				zap.L().Debug("starlark scanning events row")
				var row types.EventRow
				err := rows.Scan(&row.ID, &row.Inserted, &row.KeyId, &row.Cluster, &row.Tags, &row.Data)
				if err != nil {
					return starlark.None, err
				} else {
					d := starlark.NewDict(8)
					dataDict := GolangToStarlark(row.Data)
					d.SetKey(starlark.String("id"), starlark.MakeInt64(row.ID))
					d.SetKey(starlark.String("inserted"), starlark.String(row.Inserted.UTC().Format(time.RFC3339)))
					d.SetKey(starlark.String("key_id"), starlark.String(row.KeyId))
					d.SetKey(starlark.String("cluster"), starlark.String(row.Cluster.String))
					d.SetKey(starlark.String("tags"), starlark.String(row.Tags))
					d.SetKey(starlark.String("data"), dataDict)
					resultList.Append(d)
				}
			case "summary":
				zap.L().Debug("starlark scanning summary row")
				var row types.SummaryRow
				if err := rows.Scan(&row.ID, &row.Inserted, &row.Date, &row.KeyId, &row.Operation, &row.Tags, &row.Data); err != nil {
					return starlark.None, err
				} else {
					d := starlark.NewDict(10)
					dataDict := GolangToStarlark(row.Data)
					d.SetKey(starlark.String("id"), starlark.MakeInt64(row.ID))
					d.SetKey(starlark.String("inserted"), starlark.String(row.Inserted.UTC().Format(time.RFC3339)))
					d.SetKey(starlark.String("date"), starlark.String(row.Date))
					d.SetKey(starlark.String("key_id"), starlark.String(row.KeyId))
					d.SetKey(starlark.String("operation"), starlark.String(row.Operation))
					d.SetKey(starlark.String("tags"), starlark.String(row.Tags.String))
					d.SetKey(starlark.String("data"), dataDict)
					resultList.Append(d)
				}
			}
		}

		return resultList, nil

	}
}

func GolangToStarlark(data types.JsonMap) *starlark.Dict {
	dataDict := starlark.NewDict(64)

	zap.L().Debug("GolangToStarlark", zap.Any("data", data))

	for k, v := range data {
		switch v.(type) {
		case int:
			dataDict.SetKey(starlark.String(k), starlark.MakeInt64(int64(v.(int64))))
		case float64:
			dataDict.SetKey(starlark.String(k), starlark.Float(v.(float64)))
		case string:
			dataDict.SetKey(starlark.String(k), starlark.String(v.(string)))
		case map[string]any:
			newM := make(types.JsonMap, 0)
			for k, v := range v.(map[string]any) {
				newM[k] = v.(map[string]any)
			}
			dataDict.SetKey(starlark.String(k), GolangToStarlark(newM))
		default:
			zap.L().Debug("could not map value to starlark.Dict",
				zap.String("key", k),
				zap.Any("value", v),
				zap.String("value type", fmt.Sprintf("%T", v)))
		}
	}

	zap.L().Debug("G2S", zap.Any("starlark.Dict", dataDict))

	return dataDict
}

func StarlarkToGolang(data starlark.Value) types.JsonMap {
	zap.L().Debug("StarlarkToGolang", zap.Any("data", data))

	m := make(types.JsonMap, 0)
	for _, dk := range data.(*starlark.Dict).Keys() {
		mapk, _ := starlark.AsString(dk)
		val, _, _ := data.(*starlark.Dict).Get(dk)
		switch val.Type() {
		case "int":
			zap.L().Debug("S2G->int", zap.Any("value", val))
			num := 42
			err := starlark.AsInt(val, &num)
			if err != nil {
				zap.L().Info("S2G->int conversion error", zap.Any("value", val))
			}
			m[mapk] = num
		case "string":
			zap.L().Debug("S2G->string", zap.Any("value", val))
			m[mapk] = starlark.String(val.(starlark.String))
		case "float":
			zap.L().Debug("S2G->float", zap.Any("value", val))
			num, ok := starlark.AsFloat(val)
			if !ok {
				zap.L().Info("S2G->float conversion error", zap.Any("value", val))
			}
			m[mapk] = num
		default:
			zap.L().Debug("could not determine starlark type",
				zap.String("key", mapk),
				zap.String("starlark_type", val.Type()),
				zap.String("golang_type", fmt.Sprintf("%T", data)))
			m[mapk] = starlark.String("nope")
		}
	}

	zap.L().Debug("S2G", zap.Any("map", m))

	return m
}

func etlRunStarlark(etlP *etl.RunEtlParams, row storage.EtlRow, tx *sql.Tx) error {

	// The thread we'll execute the code in.
	thread := &starlark.Thread{Name: row.Name + "-starlark-thread"}
	// This loads standard modules, including JSON manipulation.
	// See
	// https://github.com/google/starlark-go/blob/fadfc96def35ea95e7f2bd9952256d4db1d80d91/cmd/starlark/starlark.go#L98
	starlark.Universe["json"] = starjson.Module
	starlark.Universe["time"] = startime.Module
	starlark.Universe["math"] = starmath.Module

	// Register a query function
	// This lets Starlark code call out and query the itslog_events table
	registrar := starlark.StringDict{"query": starlark.NewBuiltin("query", queryFun(etlP))}

	// This evals the file, which does not *yet* execute the code.
	// Note we register "query" as a function in the interpreted namespace.
	globals, err := starlark.ExecFileOptions(&syntax.FileOptions{Recursion: false}, thread, "", row.Body, registrar)
	if err != nil {
		return err
	}

	// Call Starlark function from Go.
	// Specifically, we're calling "summarize", which must be provided.
	fn, ok := globals["summarize"].(*starlark.Function)
	if !ok {
		log.Printf("value %v is not a Starlark function", globals["summarize"])
		return fmt.Errorf("value %v is not a Starlark function", globals["summarize"])
	}

	// Here is the call.
	v, err := starlark.Call(thread, fn, nil, nil)
	if err != nil {
		zap.L().Error("starlark Call() error",
			zap.Error(err))
		return err
	}

	// Now, we're going to construct a list of rows that are suitable for insertion into the
	// summary table from this result. We should get back a Starlark list, which will
	// contain starlark dictionaries. These need to be turned into Golang structs.
	// FIXME: what if someone wants `summary` rows? This does not work.
	// consider using map[string]any instead.
	summaries := make([]etl.ItslogSummary, 0)
	for elem := range v.(*starlark.List).Elements() {
		srjs := etl.ItslogSummary{}
		for _, k := range elem.(*starlark.Dict).Keys() {
			s, _ := starlark.AsString(k)
			switch s {
			case "operation":
				v, found, _ := elem.(*starlark.Dict).Get(k)
				if found {
					srjs.Operation, _ = starlark.AsString(v)
				}
			case "tags":
				v, found, _ := elem.(*starlark.Dict).Get(k)
				if found {
					srjs.Tags, _ = starlark.AsString(v)
				}
			case "data":
				data, found, _ := elem.(*starlark.Dict).Get(k)
				if found {
					srjs.Data = StarlarkToGolang(data)
				}
			}
		}

		zap.L().Debug("starlark summary",
			zap.String("summary", fmt.Sprintf("%v", srjs)))

		summaries = append(summaries, srjs)
	}

	// // Now, write them to the summary table.
	return InsertSummaryRows("starlark", etlP, summaries)

}
