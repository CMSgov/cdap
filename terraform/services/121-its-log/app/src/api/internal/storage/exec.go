package storage

import (
	"database/sql"
	"errors"
	"fmt"

	"go.uber.org/zap"
)

func (s *Storage) ExecNoLock(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {

	switch kind {
	case Schema:
		res, err := s.Schema.Exec(name, make([]any, 0))
		return res, err
	case Endpoint:
		if _, ok := s.Endpoints.Files[name]; ok {
			args, err := s.PrepareNamedArgs(name, params)
			if err != nil {
				zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
				return nil, err
			}
			// Get the SQL
			theSql := s.Endpoints.Files[name]
			res, err := s.db.Exec(theSql, args...)
			if err != nil {
				zap.L().Error("ExecContext failure",
					zap.String("name", name),
					zap.Any("params", params),
					zap.Any("args", args),
					zap.Error(err))
			}
			return res, err
		} else {
			return nil, fmt.Errorf("could not find stored SQL for %s", name)
		}
	default:
		zap.L().Error("Exec: unknown kind of stored SQL",
			zap.Int("kind", int(kind)),
			zap.String("name", name))
		return nil, errors.New("unknown kind of stored SQL")
	}

	// Unreachable via gopls
}

func (s *Storage) Exec(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {
	s.Lock("Exec")
	res, err := s.ExecNoLock(kind, name, params)
	s.Flush()
	s.Unlock("Exec")
	return res, err
}
