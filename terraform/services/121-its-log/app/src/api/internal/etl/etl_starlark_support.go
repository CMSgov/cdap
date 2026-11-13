package etl

import (
	"fmt"
	"strings"

	"go.starlark.net/starlark"
	"go.uber.org/zap"
)

func golangSliceToStarlark[T any](data []T) (*starlark.List, error) {
	// First, convert the array to Starlark values.
	converted := make([]starlark.Value, 0)
	for ndx, v := range data {
		c, err := GolangToStarlark(v)
		if err != nil {
			return nil, fmt.Errorf("error in array conversion ndx[%d] val[%v]", ndx, data[ndx])
		}
		converted = append(converted, c)
	}
	return starlark.NewList(converted), nil
}

// GolangToStarlark takes Golang values and converts them to
// Starlark types, so they can be passed into the interpreter.
func GolangToStarlark(data any) (starlark.Value, error) {
	// zap.L().Debug("GolangToStarlark", zap.Any("data", data))

	// If we're converting a Golang nil value, send back
	// the starlark.None value. Do this first so that we don't
	// try and do any operations on a `nil` value.
	if data == nil {
		return starlark.None, nil
	}

	// if isSlice(data) {
	// 	// Check what the first value is.
	// 	starlarkList, err := golangSliceToStarlark(data)
	// }

	// Otherwise, branch on the type. We'll convert Golang values
	// into the appropriate Starlark values here, for passing to the
	// interpreter for use.
	switch data := data.(type) {
	case float64:
		return starlark.Float(data), nil
	case int:
		// Starlark only knows int64s. So, when testing round trips,
		// expect that an `int` will turn into an `int64`.
		return starlark.MakeInt64(int64(data)), nil
	case int64:
		return starlark.MakeInt64(int64(data)), nil
	case map[string]any:
		sd := starlark.NewDict(32)
		for k, v := range data {
			conv, err := GolangToStarlark(v)
			if err != nil {
				return nil, fmt.Errorf("could not convert v in dict: %v", v)
			}
			sd.SetKey(starlark.String(k), conv)
		}
		return sd, nil
	case string:
		return starlark.String(data), nil
	case []any:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil

	case []float64:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil
	case []int:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil
	case []int64:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil
	case []map[string]any:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil
	case []string:
		sl, err := golangSliceToStarlark(data)
		if err != nil {
			return nil, fmt.Errorf("could not convert array of type %T", data)
		}
		return sl, nil
	default:
		zap.L().Debug("could not map value to starlark.Value",
			zap.Any("data", data),
			zap.String("data type", fmt.Sprintf("%T", data)))
		return nil, fmt.Errorf("could not map golang type to starlark: %T", data)
	}
}

func allElementsSame[T comparable](arr []T) bool {
	if len(arr) <= 1 {
		return true
	}
	for i := 1; i < len(arr); i++ {
		if arr[i] != arr[0] {
			return false
		}
	}
	return true
}

func getListType(ls *starlark.List) string {
	nonNilLen := 0
	for e := range ls.Elements() {
		if e != nil {
			nonNilLen += 1
		}
	}
	types := make([]string, 0)
	for e := range ls.Elements() {
		if e != nil && !strings.Contains(e.Type(), "None") {
			t := e.Type()
			if len(t) > 0 {
				types = append(types, t)
			}
		}
	}
	if allElementsSame(types) {
		if types[0] == "int" {
			return "int64"
		} else {
			return types[0]
		}
	} else {
		return "any"
	}
}

func convertStarlarkList[T any](data *starlark.List) ([]T, error) {
	arr := make([]T, 0)
	for elem := range data.Elements() {
		if elem != nil {
			v, err := StarlarkToGolang(elem)
			if err != nil {
				return nil, fmt.Errorf("error in list conversion: %s", v)
			}
			arr = append(arr, v.(T))
		}
	}
	return arr, nil
}

// Values in the interpreter are Starlark types; before returning
// things back to Golang, we have to convert them.
// See: https://github.com/google/starlark-go/blob/master/starlark/value.go
func StarlarkToGolang(data starlark.Value) (any, error) {
	zap.L().Debug("StarlarkToGolang",
		zap.Any("data", data),
		zap.String("type", data.Type()))

	switch data.Type() {
	case "dict":
		m := make(map[string]any)
		for k, v := range data.(*starlark.Dict).Entries() {
			conv, err := StarlarkToGolang(v)
			if err != nil {
				return nil, fmt.Errorf("error converting in starlark dict %s[%v]", k.String(), v)
			}
			unquoted := k.(starlark.String).GoString()
			m[unquoted] = conv
		}
		return m, nil
	case "float":
		f64, _ := starlark.AsFloat(data)
		return f64, nil
	case "int":
		var i int64
		starlark.AsInt(data, &i)
		return i, nil
	case "int64":
		var i int64
		starlark.AsInt(data, &i)
		return i, nil
	case "list":
		t := getListType(data.(*starlark.List))
		switch t {
		case "any":
			ls, err := convertStarlarkList[any](data.(*starlark.List))
			if err != nil {
				return nil, err
			}
			return ls, nil
		case "int":
			// All lists of integers in Starlark will contain
			// values of type starlark.Int. We want those to always
			// come back as int64 values. So, catch this as type int64.
			ls, err := convertStarlarkList[int64](data.(*starlark.List))
			if err != nil {
				return nil, err
			}
			return ls, nil
		case "int64":
			ls, err := convertStarlarkList[int64](data.(*starlark.List))
			if err != nil {
				return nil, err
			}
			return ls, nil
		case "float64":
			ls, err := convertStarlarkList[float64](data.(*starlark.List))
			if err != nil {
				return nil, err
			}
			return ls, nil
		case "string":
			ls, err := convertStarlarkList[string](data.(*starlark.List))
			if err != nil {
				return nil, err
			}
			return ls, nil
		default:
			return nil, fmt.Errorf("unknown type in list conversion: %s", t)
		}
	case "NoneType":
		return nil, nil
	case "string":
		repr := data.(starlark.String).GoString()
		return repr, nil
	default:
		zap.L().Error("could not handle S2G type",
			zap.String("type", data.Type()))
		return nil, fmt.Errorf("could not handle S2G type: %s", data.Type())
	}
}
