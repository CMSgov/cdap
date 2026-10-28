-- name: GetAllSummaries :many
PREPARE get_all_summaries AS
  SELECT * FROM itslog_summary;
