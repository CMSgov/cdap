PREPARE export_to_s3 AS
    COPY tbl TO $bucket + '/output.csv' (HEADER, DELIMITER ',');

