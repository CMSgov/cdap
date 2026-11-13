package etl

import (
	"reflect"
	"testing"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"go.starlark.net/starlark"
)

type M types.M

var tests = []struct {
	value any
}{
	{nil},
	{int64(42)},
	{"hello"},
	{42.42},
	{map[string]any{"life": int64(64)}},
	{types.M{"hello": "goodbye"}},
	{types.M{"hello": "\"goodbye\""}},
	{types.M{"hello": "goodbye", "one": "two"}},
	{types.M{"hello": "goodbye", "one": 42.42}},
	{types.M{"hello": types.M{"deeper": int64(42)}}},
	{types.M{"hello": types.M{"deeper": types.M{"hello": types.M{"deeper": 42.42}}}}},
	{[]string{"hello", "goodbye"}},
	// We have no way, when coming bask from Starlark, of knowing
	// that a list of only strings is of "any" type. So, this is an impossible
	// test case. If a list is of a single type, it will be typed as that type.
	// {[]any{"hello", "goodbye"}},
	// There are no int values that come back from Starlark; they are all
	// int64 values.
	{[]any{"wat", int64(8)}},
}

func TestValueToStarlark(t *testing.T) {

	for _, tt := range tests {
		t.Logf("tt.value: %v", tt.value)
		_, err := GolangToStarlark(tt.value)
		if err != nil {
			t.Error(err.Error())
		}
	}
}

func TestGetListType(t *testing.T) {
	var tests = []struct {
		ls *starlark.List
		t  string
	}{
		{starlark.NewList([]starlark.Value{starlark.String("hi")}), "string"},
		{starlark.NewList([]starlark.Value{starlark.String("hi"), starlark.String("bye")}), "string"},
		{starlark.NewList([]starlark.Value{starlark.String("hi"), starlark.MakeInt(8)}), "any"},
		// All arrays of ints will come back as arrays of int64 values
		{starlark.NewList([]starlark.Value{starlark.MakeInt(3)}), "int64"},
		{starlark.NewList([]starlark.Value{starlark.MakeInt64(int64(5))}), "int64"},
	}
	for _, tt := range tests {
		ret := getListType(tt.ls)
		if ret != tt.t {
			t.Errorf("types do not match: %s != %s", ret, tt.t)
		}
	}
}

func TestValueRoundTrip(t *testing.T) {

	for _, tt := range tests {
		t.Logf("tt.value: %v", tt.value)
		sv, err := GolangToStarlark(tt.value)
		if err != nil {
			t.Error(err.Error())
		}
		gv, err := StarlarkToGolang(sv)
		if err != nil {
			t.Error(err.Error())
		}
		isDeep := reflect.DeepEqual(tt.value, gv)
		if isDeep {
			t.Log("yay")
		} else {
			t.Errorf("not a deep match\n%s\n%s", tt.value, gv)
		}
	}
}
