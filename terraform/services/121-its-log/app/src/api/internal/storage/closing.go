package storage

import (
	"database/sql"
	"log"
	"os"
	"path"

	"github.com/spf13/viper"
	"go.uber.org/zap"
)

func (s *Storage) Close() {
	zap.L().Info("database closed via s.Close()")
	if s.Context != nil {
		s.Context.Done()
		s.Context = nil
	}
	if s.db != nil {
		s.db.Close()
		s.db = nil
	}
	// Give it the old college try...
	if s.lock.TryLock() {
		// This means the lock was acquired...
		defer s.lock.Unlock()
	} else {
		// It is locked. Unlock it.
		defer s.lock.Unlock()
	}

	// If the DB is closed, kill the entire storage pointer.
	// s = nil
}

func (s *Storage) Flush() {
	// This flushes any outstanding actions/transactions on the DuckDB.
	// Good to do before closing the file or doing any operations on the DB file itself.
	_, err := s.db.Exec("CHECKPOINT;")
	if err != nil {
		// Try once more, after trying to open the database.
		zap.L().Info("failed to checkpoint; retrying")
		if DoesDBExist(s.Path) {
			// It exists. Lets try to open it. For some reason, we were closed.
			// s.db, s.connector, s.Context, err = openDatabase(path.Join(s.Path...))
			db, err := sql.Open("duckdb", path.Join(s.Path...))
			if err != nil {
				msg := "tried to reopen the database, could not"
				zap.L().Error(msg, zap.Error(err))
				panic(msg)
			}
			s.db = db
			zap.L().Info("had to reopen the datbase",
				zap.String("app_id", s.AppId),
				zap.String("filename", s.Filename),
				zap.String("date", s.YYYYMMDD()))
			_, err = s.db.Exec("CHECKPOINT;")
			if err != nil {
				msg := "failed to checkpoint twice"
				zap.L().Error(msg, zap.Error(err))
				panic(err)
			}
		} else {
			msg := "could not checkpoint the db"
			zap.L().Error(msg, zap.Error(err))
			panic(msg)
		}
	}

}

func (s *Storage) Delete() {
	s.Flush()
	s.db.Close()
	path := path.Join(viper.GetString("storage.path"), s.Filename)
	log.Printf("Deleting database: %s", path)
	os.Remove(path)
}
