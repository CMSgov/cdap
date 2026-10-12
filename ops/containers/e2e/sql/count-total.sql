WITH total_count (TC) AS (
    SELECT count(*) from itslog_events
)
INSERT INTO itslog_summary
    (key_id, date, operation, tags, value, count)
VALUES
    ($key_id, $date, 'count.total', '', '', (select TC from total_count))
RETURNING 0;

-- V0lUSCB0b3RhbF9jb3VudCAoVEMpIEFTICgKICAgIFNFTEVDVCBjb3VudCgqKSBmcm9tIGl0c2xvZ19ldmVudHMKKQpJTlNFUlQgSU5UTyBpdHNsb2dfc3VtbWFyeQogICAgKGtleV9pZCwgZGF0ZSwgb3BlcmF0aW9uLCB0YWdzLCB2YWx1ZSwgY291bnQpClZBTFVFUwogICAgKCRrZXlfaWQsICRkYXRlLCAnY291bnQudG90YWwnLCAnJywgJycsIChzZWxlY3QgVEMgZnJvbSB0b3RhbF9jb3VudCkpClJFVFVSTklORyAwOwo=