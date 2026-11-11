INSERT INTO summary (
    key_id, operation, tags, data
    ) VALUES (
    $key_id, $operation, $tags::JSON, $data::JSON
    )
ON CONFLICT (operation, tags) DO UPDATE SET
    inserted = NOW(),
    key_id = EXCLUDED.key_id,
    operation = EXCLUDED.operation,
    tags = EXCLUDED.tags,
    data = EXCLUDED.data,
;