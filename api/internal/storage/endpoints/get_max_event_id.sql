PREPARE get_max_event_id AS
    SELECT max(id) from itslog_events LIMIT 1;
    