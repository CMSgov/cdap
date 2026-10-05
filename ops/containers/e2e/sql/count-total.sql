WITH total_count (TC) AS (
    SELECT count(*) from itslog_events
)
INSERT INTO itslog_summary
    (key_id, date, operation, tags, value, count)
VALUES
    ($key_id, $date, 'count.total', '', '', (select TC from total_count)*2)
-- Everything must have gone fine. 
-- Return 0 for success.
RETURNING 0;