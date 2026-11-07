package storage

// func ExecNoLock(im IMetabase, name string, params EmbedParamMap) (sql.Result, error) {
// 	if EmbeddedSchema.Contains(name) {

// 	}
// 	if EmbeddedEndpoints.Contains(name) {
// 		args, err := EmbeddedEndpoints.PrepareNamedArgs(name, params)
// 		if err != nil {
// 			zap.L().Error("error in PrepareNamedArgs", zap.Error(err))
// 			return nil, err
// 		}
// 		// Get the SQL
// 		theSql, err := EmbeddedEndpoints.Get(name)
// 		if err != nil {
// 			return nil, err
// 		}
// 		res, err := im.GetDB().Exec(theSql, args...)
// 		if err != nil {
// 			zap.L().Error("ExecContext failure",
// 				zap.String("name", name),
// 				zap.Any("params", params),
// 				zap.Any("args", args),
// 				zap.Error(err))
// 		}
// 		return res, err
// 	} else {
// 		return nil, fmt.Errorf("could not find stored SQL for %s", name)
// 	}
// }

// func (s *Storage) Exec(kind StoredSql, name string, params EmbedParamMap) (sql.Result, error) {
// 	s.Lock("Exec")
// 	res, err := s.ExecNoLock(kind, name, params)
// 	s.Flush()
// 	s.Unlock("Exec")
// 	return res, err
// }
