package storage

// func (s *Storage) Query(name string, params EmbedParamMap) (*sql.Rows, error) {

// 	args, err := s.PrepareNamedArgs(name, params)
// 	if err != nil {
// 		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
// 		return nil, err
// 	}
// 	s.Lock("Query")
// 	res, err := s.Endpoints.Query(name, args)
// 	s.Unlock("Query")
// 	if err != nil {
// 		return nil, err
// 	}
// 	return res, nil

// }

// func (s *Storage) QueryRow(name string, params EmbedParamMap) *sql.Row {
// 	var row *sql.Row
// 	s.Lock("QueryRow")
// 	args, err := s.PrepareNamedArgs(name, params)
// 	if err != nil {
// 		zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
// 		s.Unlock("QueryRow")
// 		return nil
// 	}
// 	row = s.db.QueryRow(s.Endpoints.Files[name], args...)
// 	s.Unlock("QueryRow")

// 	return row
// }
