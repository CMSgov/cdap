package metabase

import (
	"testing"

	"github.com/navapbc/its-log/internal/types"
)

func TestGenerateNamedArgs(t *testing.T) {
	s1 := "select from x where tags = getvariable('bigbird') and foo = $tags amd bar = $asdf"
	_, err := generateNamedArgs(s1, types.M{
		"tags":    "hello",
		"bigbird": 3,
		"asdf": types.M{
			"hi": "bye",
		},
	})
	if err != nil {
		t.Error(err)
	}
}
