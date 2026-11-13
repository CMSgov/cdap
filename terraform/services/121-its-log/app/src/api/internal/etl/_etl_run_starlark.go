package etl

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
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
		if err != nil {
			return nil, err
		}

		// Make sure we don't have INSERT, DELETE, or UPDATE queries from starlark.
		for _, naughty := range []string{"insert", "delete", "update"} {
			if strings.Contains(strings.ToLower(queryString), naughty) {
				return nil, fmt.Errorf("starlark query cannot contain %s", naughty)
			}
		}

		// An SQL step will read from the DB.
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
					dataDict, err := GolangToStarlark(row.Data)
					if err != nil {
						return nil, err
					}
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
				if err := rows.Scan(&row.ID, &row.Inserted, &row.KeyId, &row.Operation, &row.Tags, &row.Data); err != nil {
					return starlark.None, err
				} else {
					d := starlark.NewDict(10)
					dataDict, err := GolangToStarlark(row.Data)
					if err != nil {
						return nil, err
					}
					d.SetKey(starlark.String("id"), starlark.MakeInt64(row.ID))
					d.SetKey(starlark.String("inserted"), starlark.String(row.Inserted.UTC().Format(time.RFC3339)))
					// d.SetKey(starlark.String("date"), starlark.String(row.Date))
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
					data, err := StarlarkToGolang(data)
					if err != nil {
						return err
					}
					srjs.Data = data.(map[string]any)
				}
			}
		}

		zap.L().Debug("starlark summary",
			zap.String("summary", fmt.Sprintf("%v", srjs)))

		summaries = append(summaries, srjs)
	}

	etlP.DeleteBeforeInsert = true
	// // Now, write them to the summary table.
	return InsertSummaryRows("starlark", etlP, summaries)

}
