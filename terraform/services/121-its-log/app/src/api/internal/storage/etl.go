package storage

import (
	"errors"
	"fmt"

	"go.uber.org/zap"
)

func (s *Storage) GetEtlFromDb(name string) (EtlRow, error) {
	raw := s.QueryRow(Endpoint,
		"get_etl",
		EmbedParamMap{"name": name})

	// var name, kind, body, lastRun string
	//err := row.Scan(&name, &kind, &body, &lastRun)
	var etlRow EtlRow
	err := raw.Scan(&etlRow.Name, &etlRow.Kind, &etlRow.Body)

	if err != nil {
		msg := "could not get etl from db"
		zap.L().Error(msg,
			zap.String("etl_name", name),
			zap.Error(err),
		)
		return EtlRow{}, errors.New(msg)
	}
	return etlRow, nil
}

// Consumes the name of embedded SQL and a parameter map.
// Finds the named params in the SQL (which must begin with $_)
// and looks up the name in the map, returning a list of sql.NamedArgs
// matching the variables needed to execute the SQL
func (s *Storage) PrepareNamedArgs(name string, params EmbedParamMap) ([]any, error) {
	// Look for the named params expected in the SQL
	var theSql string
	if _, ok := s.Endpoints.Files[name]; !ok {
		etlRow, err := s.GetEtlFromDb(name)
		if err != nil {
			return nil, fmt.Errorf("could not prepare args for %s; not found", name)
		}
		theSql = etlRow.Body
	} else {
		theSql = s.Endpoints.Files[name]
	}
	named, err := GenerateNamedArgs(theSql, params)
	if err != nil {
		return nil, err
	}
	return named, nil
}
