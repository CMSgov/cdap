package etl

import (
	"fmt"

	"github.com/navapbc/its-log/internal/etl"
)

func hasExpectedKeys(stepName string, etlP *etl.RunEtlParams, jsonKeyList []string) error {
	for _, key := range jsonKeyList {
		_, ok := etlP.Payload[key]
		if !ok {
			return fmt.Errorf("missing parameter %s for %s", key, stepName)
		}
	}
	return nil
}
