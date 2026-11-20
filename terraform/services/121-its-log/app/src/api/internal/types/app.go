package types

import (
	"fmt"
	"math/rand/v2"

	"github.com/google/uuid"
)

type App struct {
	AppId string
	KeyId string
}

func RandomApp(base string) App {
	return App{
		AppId: fmt.Sprintf("%s-%04d", base, rand.IntN(1000)),
		KeyId: base + "_" + uuid.NewString(),
	}
}
