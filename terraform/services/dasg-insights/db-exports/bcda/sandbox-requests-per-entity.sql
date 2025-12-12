SELECT cron.schedule_in_database(
  's3_export_bcda_sandbox_requests_per_entity',
  '0 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM bcda_sandbox_requests_per_entity',
      aws_commons.create_s3_uri
      (
        'bcda-sandbox-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'bcda-sandbox-requests-per-entity.csv',
        'us-east-1'
      ),
      options := 'format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'bcda'
);
