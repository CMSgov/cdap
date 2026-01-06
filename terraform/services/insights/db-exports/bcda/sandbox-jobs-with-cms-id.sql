SELECT cron.schedule_in_database(
  's3_export_bcda_jobs_with_cms_id',
  '10 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM bcda_jobs_with_cms_id',
      aws_commons.create_s3_uri
      (
        'bcda-sandbox-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'bcda-jobs-with-cms-id.csv',
        'us-east-1'
      ),
      options := 'format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'bcda'
);