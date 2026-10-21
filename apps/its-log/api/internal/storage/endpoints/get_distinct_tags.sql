-- name: GetDistinctTags :many
PREPARE get_distinct_tags AS
    SELECT DISTINCT tags
    FROM itslog_events;