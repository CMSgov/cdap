SELECT cron.schedule_in_database(
  's3_export_bcda_prod_active_acos',
  '0 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM bcda_prod_active_acos',
      aws_commons.create_s3_uri
      (
        'bcda-prod-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'bcda-prod-active-acos.csv',
        'us-east-1'
      ),
      options := 'format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'bcda'
);
