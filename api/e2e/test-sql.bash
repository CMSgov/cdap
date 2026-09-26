#!/bin/bash

DB="test.duckdb"

rm -f test.duckdb
cat ../internal/schema/sql/schema.sql | duckdb $DB

for i in $(seq 1 10); do
    duckdb $DB "INSERT INTO  
done