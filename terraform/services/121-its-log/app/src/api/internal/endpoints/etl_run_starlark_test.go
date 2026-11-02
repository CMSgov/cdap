package endpoints

import (
	"reflect"
	"testing"

	"github.com/navapbc/its-log/internal/types"
)

type M types.M

func TestValueRoundTrip(t *testing.T) {
	var tests = []struct {
		value any
	}{
		{nil},
		{int64(42)},
		{"hello"},
		{42.42},
		{map[string]any{"life": int64(64)}},
		{types.M{"hello": "goodbye"}},
		{types.M{"hello": types.M{"deeper": int64(42)}}},
	}

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
		if reflect.DeepEqual(tt.value, gv) {
			t.Log("yay")
		} else {
			t.Errorf("not a deep match\n%s\n%s", tt.value, gv)
		}
	}
}
