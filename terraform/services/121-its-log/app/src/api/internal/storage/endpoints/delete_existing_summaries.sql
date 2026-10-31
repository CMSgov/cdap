DELETE FROM itslog_summary 
WHERE
    key_id = $key_id
    AND
    date = $date
    AND
    operation = $operation;
