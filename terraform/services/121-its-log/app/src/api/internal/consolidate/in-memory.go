package consolidate

import (
	"database/sql"
	"errors"
)

func GetInMemoryDB() (*sql.DB, error) {
	// Source database(s)
	inMem, err := sql.Open("duckdb", ":memory:")
	if err != nil {
		// ServerError(c, err, "could not open in-memory database")
		return nil, errors.New("could not create in-memory db")
	}

	return inMem, nil
}
