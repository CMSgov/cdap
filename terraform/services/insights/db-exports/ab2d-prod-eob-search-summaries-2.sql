CREATE VIEW ab2d_prod_eob_search_summaries_2 AS
  SELECT 
    job_uuid,
    jv.contract_number,
    jv.contract_name,
    jv.organization,
    created_at,
    completed_at,
    expires_at,
    resource_types,
    status,
    request_url,
    output_format,
    since,
    fhir_version,
    year_week,
    week_start,
    week_end,
    benes_expected,
    benes_searched,
    num_opted_out,
    benes_errored,
    benes_queued,
    eobs_fetched,
    eobs_written,
    eob_files,
    EXTRACT(epoch FROM (completed_at - created_at)) / 60 AS job_time_minutes,
    age(date_trunc('minute', completed_at),
    date_trunc('minute', created_at))::TEXT AS job_time
  FROM event.event_bene_search ebs
  RIGHT JOIN job_view jv 
  ON ebs.job_id = jv.job_uuid;

==========

SELECT cron.schedule_in_database(
  's3_export_ab2d_prod_eob_search_summaries_2',
  '0 */6 * * *',
  $$
    SELECT *
    FROM aws_s3.query_export_to_s3
    (
      'SELECT * FROM ab2d_prod_eob_search_summaries_2',
      aws_commons.create_s3_uri
      (
        'ab2d-prod-aurora-export-2025xxxxxxxxxxxxxxxxxxxxxx',
        'ab2d-prod-eob-search-summaries-2.csv',
        'us-east-1'
      ),
      options :='format csv, HEADER true',
      kms_key => '<aurora_export key arn>'
    );
  $$,
  'main'
);
