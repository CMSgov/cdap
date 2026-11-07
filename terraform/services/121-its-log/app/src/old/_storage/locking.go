package storage

import "go.uber.org/zap"

func (s *Storage) Lock(location string) {
	zap.L().Debug("== Lock ==",
		zap.String("app_id", s.AppId),
		zap.String("date", s.YYYYMMDD()),
		zap.String("location", location))
	s.lock.Lock()

}

func (s *Storage) Unlock(location string) {

	zap.L().Debug("== Unlock ==",
		zap.String("app_id", s.AppId),
		zap.String("date", s.YYYYMMDD()),
		zap.String("location", location))
	s.lock.Unlock()
}
