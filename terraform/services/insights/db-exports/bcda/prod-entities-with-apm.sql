SELECT cron.schedule_in_database(
  's3_export_bcda_prod_entities_with_apm',
  '45 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM bcda_prod_entities_with_apm',
      aws_commons.create_s3_uri
      (
        'bcda-prod-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'bcda-prod-entities-with-apm.csv',
        'us-east-1'
      ),
      options := 'format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'bcda'
);
