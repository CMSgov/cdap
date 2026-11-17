package etl

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/embedfs"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/metabase"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/types"
	starjson "go.starlark.net/lib/json"
	starmath "go.starlark.net/lib/math"
	startime "go.starlark.net/lib/time"

	"go.starlark.net/starlark"
	"go.starlark.net/syntax"
	"go.uber.org/zap"
)

// -----------
// Running Starlark ETLs
func RunStarlark(m *metabase.Metabase, etlb RunEtlBody, row types.EtlRow) ([]types.EtlRunResult, error) {

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
	registrar := starlark.StringDict{"query": starlark.NewBuiltin("query", queryFun(m, etlb))}

	// This evals the file, which does not *yet* execute the code.
	// Note we register "query" as a function in the interpreted namespace.
	globals, err := starlark.ExecFileOptions(&syntax.FileOptions{Recursion: false}, thread, "", row.Body, registrar)
	if err != nil {
		return nil, err
	}

	// Call Starlark function from Go.
	// Specifically, we're calling "summarize", which must be provided.
	fn, ok := globals["summarize"].(*starlark.Function)
	if !ok {
		log.Printf("value %v is not a Starlark function", globals["summarize"])
		return nil, fmt.Errorf("value %v is not a Starlark function", globals["summarize"])
	}

	// Here is the call.
	v, err := starlark.Call(thread, fn, nil, nil)
	if err != nil {
		zap.L().Error("starlark Call() error",
			zap.Error(err))
		return nil, err
	}
	// FIXME: Add some checking to make sure the ETL
	// returns a Starlark list, so the case below works

	// Now, we're going to construct a list of rows that are suitable for insertion into the
	// summary table from this result. We should get back a Starlark list, which will
	// contain starlark dictionaries. These need to be turned into Golang structs.
	// FIXME: what if someone wants `summary` rows? This does not work.
	// consider using map[string]any instead.
	summaries := make([]types.EtlRunResult, 0)
	for elem := range v.(*starlark.List).Elements() {
		srjs := types.EtlRunResult{}
		for _, k := range elem.(*starlark.Dict).Keys() {
			s, _ := starlark.AsString(k)
			switch s {
			case "date":
				v, found, _ := elem.(*starlark.Dict).Get(k)
				if found {
					srjs.Date, _ = starlark.AsString(v)
				}
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
					data, err := StarlarkToGolang(data)
					if err != nil {
						return nil, err
					}
					srjs.Data = data.(map[string]any)
				}
			}
		}

		trimmed, err := types.TrimToYYYYMMDD(srjs.Date)
		if err != nil {
			if len(srjs.Date) == 0 {
				return nil, fmt.Errorf("no date returned in starlark summary row")
			} else {
				return nil, fmt.Errorf("bad date from starlark summary: ['%s']", srjs.Date)
			}
		}
		srjs.Date = trimmed

		zap.L().Debug("starlark summary",
			zap.String("summary", fmt.Sprintf("%v", srjs)))

		summaries = append(summaries, srjs)
	}

	return summaries, nil
}

func queryFun(m *metabase.Metabase, etlb RunEtlBody) func(_ *starlark.Thread, _ *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	return func(_ *starlark.Thread, _ *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
		var queryTable string
		var queryString string
		if err := starlark.UnpackArgs(
			"config", args, kwargs,
			"table", &queryTable, "query", &queryString,
		); err != nil {
			return starlark.None, fmt.Errorf("config: %s", err)
		}

		// Make sure we don't have INSERT, DELETE, or UPDATE queries from starlark.
		for _, naughty := range []string{"insert", "delete", "update"} {
			if strings.Contains(strings.ToLower(queryString), naughty) {
				return nil, fmt.Errorf("starlark query cannot contain %s", naughty)
			}
		}
		// We now want to run the query from starlark, so it has data to operate on.
		// An SQL step will read from the DB.

		// Do we need to lock for a read-only operation?
		// How does the DuckDB/Golang driver handle this?
		// lockMsg := "starlark:queryfun:" + etlb.Name
		// m.Lock(lockMsg)
		rows, err := metabase.QueryNoLock(m, queryString, []embedfs.EmbeddedParam{
			{Name: "key_id", Value: etlb.App.KeyId, Type: embedfs.EmbeddedString},
			{Name: "app_id", Value: etlb.App.AppId, Type: embedfs.EmbeddedString},
			{Name: "date", Value: etlb.YMD, Type: embedfs.EmbeddedString},
		})
		// m.Unlock(lockMsg)
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
				var row types.EventRow
				err := rows.Scan(&row.ID, &row.Inserted, &row.KeyId, &row.Cluster, &row.Tags, &row.Data)
				if err != nil {
					return starlark.None, err
				} else {
					tagArr, err := GolangToStarlark(row.Tags)
					if err != nil {
						return nil, err
					}
					d := starlark.NewDict(8)
					dataDict, err := GolangToStarlark(row.Data)
					if err != nil {
						return nil, err
					}
					d.SetKey(starlark.String("id"), starlark.MakeInt64(row.ID))
					d.SetKey(starlark.String("inserted"), starlark.String(row.Inserted.UTC().Format(time.RFC3339)))
					d.SetKey(starlark.String("key_id"), starlark.String(row.KeyId))
					d.SetKey(starlark.String("cluster"), starlark.String(row.Cluster))
					d.SetKey(starlark.String("tags"), tagArr)
					d.SetKey(starlark.String("data"), dataDict)
					resultList.Append(d)
				}
			case "summary":
				var row types.SummaryRow
				if err := rows.Scan(&row.ID, &row.Inserted, &row.KeyId, &row.Date, &row.Operation, &row.Tags, &row.Data); err != nil {
					return starlark.None, err
				} else {
					tagArr, err := GolangToStarlark(row.Tags)
					if err != nil {
						zap.L().Info("error converting tags", zap.Any("row.Tags", row.Tags))
						return starlark.None, err
					}
					d := starlark.NewDict(10)
					dataDict, err := GolangToStarlark(row.Data)
					if err != nil {
						zap.L().Info("error converting data", zap.Any("row.Data", row.Data))
						return starlark.None, err
					}
					d.SetKey(starlark.String("id"), starlark.MakeInt64(row.ID))
					d.SetKey(starlark.String("inserted"), starlark.String(row.Inserted.UTC().Format(time.RFC3339)))
					d.SetKey(starlark.String("key_id"), starlark.String(row.KeyId))
					trimmed, err := types.TrimToYYYYMMDD(row.Date)
					if err != nil {
						return starlark.None, err
					}
					d.SetKey(starlark.String("date"), starlark.String(trimmed))
					d.SetKey(starlark.String("operation"), starlark.String(row.Operation))
					d.SetKey(starlark.String("tags"), tagArr)
					d.SetKey(starlark.String("data"), dataDict)
					zap.L().Debug("summary dict", zap.Any("dict", d))
					resultList.Append(d)
				}
			}
		}

		return resultList, nil
	}
}
