package endpoints

import (
	"errors"
	"fmt"
	"strconv"

	"go.starlark.net/starlark"
	"go.uber.org/zap"
)

func GolangToStarlark(data any) (starlark.Value, error) {

	zap.L().Debug("GolangToStarlark", zap.Any("data", data))
	// If we're converting a Golang nil value, send back
	// the starlark.None value.
	if data == nil {
		return starlark.None, nil
	}
	// Otherwise, branch.
	switch data.(type) {
	case int:
		// Starlark only knows int64s. So, when testing round trips,
		// expect that an `int` will turn into an `int64`.
		return starlark.MakeInt64(int64(data.(int))), nil
	case int64:
		return starlark.MakeInt64(int64(data.(int64))), nil
	case float64:
		return starlark.Float(data.(float64)), nil
	case string:
		return starlark.String(data.(string)), nil
	case map[string]any:
		sd := starlark.NewDict(32)
		for k, v := range data.(map[string]any) {
			conv, err := GolangToStarlark(v)
			if err != nil {
				return nil, fmt.Errorf("could not convert v in dict: %v", v)
			}
			sd.SetKey(starlark.String(k), conv)
		}
		return sd, nil
	default:
		zap.L().Debug("could not map value to starlark.Value",
			zap.Any("data", data),
			zap.String("data type", fmt.Sprintf("%T", data)))
		return nil, fmt.Errorf("could not map golang type to starlark: %T", data)
	}
}

func StarlarkToGolang(data starlark.Value) (any, error) {
	zap.L().Debug("StarlarkToGolang", zap.Any("data", data))

	switch data.Type() {
	case "int":
		var i int64
		starlark.AsInt(data, &i)
		return i, nil
	case "int64":
		var i int64
		starlark.AsInt(data, &i)
		return i, nil
	case "float":
		f64, _ := starlark.AsFloat(data)
		return f64, nil
	case "string":
		repr := data.(starlark.String).String()
		unquoted, err := strconv.Unquote(repr)
		return unquoted, err
	case "NoneType":
		return nil, nil
	case "dict":
		m := make(map[string]any)
		for k, v := range data.(*starlark.Dict).Entries() {
			conv, err := StarlarkToGolang(v)
			if err != nil {
				return nil, fmt.Errorf("error converting in starlark dict %s[%v]", k.String(), v)
			}
			unquoted, err := strconv.Unquote(k.String())
			if err != nil {
				return nil, fmt.Errorf("error unquoting key %s", k.String())
			}
			m[unquoted] = conv
		}
		return m, nil
	default:
		zap.L().Error("could not handle S2G type",
			zap.String("type", data.Type()))
		return nil, errors.New("could not handle S2G type")
	}
}
