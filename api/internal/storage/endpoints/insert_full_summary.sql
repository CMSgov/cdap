INSERT INTO itslog_summary (
    key_id, date, operation, tags, value, count, hash
    ) VALUES (
    $key_id, $date, $operation, $tags, $value, $count, $hash
    )
RETURNING 0;