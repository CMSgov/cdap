INSERT INTO summary (
    key_id, date, operation, tags, data
    ) VALUES (
    $key_id, $date, $operation, $tags::JSON, $data::JSON
    )
ON CONFLICT (date, operation, tags) DO UPDATE SET
    inserted = NOW(),
    date = EXCLUDED.date,
    key_id = EXCLUDED.key_id,
    operation = EXCLUDED.operation,
    tags = EXCLUDED.tags,
    data = EXCLUDED.data
;