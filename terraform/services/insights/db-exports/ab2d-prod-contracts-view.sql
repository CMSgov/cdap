SELECT cron.schedule_in_database(
  's3_export_ab2d_prod_contracts_view',
  '0 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM ab2d_prod_contracts_view',
      aws_commons.create_s3_uri
      (
        'ab2d-prod-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'ab2d-prod-contracts-view.csv',
        'us-east-1'
      ),
      options :='format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'main'
);
