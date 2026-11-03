package storage

import (
	"database/sql"
	"errors"

	"go.uber.org/zap"
)

func (s *Storage) Query(kind StoredSql, name string, params EmbedParamMap) (*sql.Rows, error) {

	switch kind {
	case Schema:
		msg := "cannot query a schema"
		zap.L().Error(msg)
		return nil, errors.New(msg)
	case Endpoint:
		args, err := s.PrepareNamedArgs(name, params)
		if err != nil {
			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
			return nil, err
		}
		s.Lock("Query")
		res, err := s.Endpoints.Query(name, args)
		s.Unlock("Query")
		if err != nil {
			return nil, err
		}
		return res, nil
	default:
		msg := "query: unknown kind of stored SQL"
		zap.L().Error(msg,
			zap.Int("kind", int(kind)),
			zap.String("name", name))
		return nil, errors.New(msg)
	}

}

func (s *Storage) QueryRow(kind StoredSql, name string, params EmbedParamMap) *sql.Row {
	var row *sql.Row
	s.Lock("QueryRow")
	switch kind {
	case Endpoint:
		args, err := s.PrepareNamedArgs(name, params)
		if err != nil {
			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
			s.Unlock("QueryRow")
			return nil
		}
		row = s.db.QueryRow(s.Endpoints.Files[name], args...)
	default:
		zap.L().Error("Query: unknown kind of stored sql",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
	}
	s.Unlock("QueryRow")

	return row
}
