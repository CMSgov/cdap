DELETE FROM itslog_summary 
WHERE
    key_id = $key_id
    AND
    operation = $operation
;
