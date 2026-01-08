SELECT cron.schedule_in_database(
  's3_export_bcda_prod_job_request_calls_weekly',
  '40 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM bcda_prod_job_request_calls_weekly',
      aws_commons.create_s3_uri
      (
        'bcda-prod-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'bcda-prod-api-calls-weekly.csv',
        'us-east-1'
      ),
      options := 'format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'bcda'
);
