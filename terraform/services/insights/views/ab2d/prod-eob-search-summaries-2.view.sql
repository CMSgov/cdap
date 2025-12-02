CREATE VIEW ab2d_prod_eob_search_summaries_2 AS
  SELECT 
    job_uuid,
    jv.contract_number,
    jv.contract_name,
    jv.organization,
    TO_CHAR(created_at, 'yyyy-MM-ddThh:mm:ss') created_at,
    TO_CHAR(completed_at, 'yyyy-MM-ddThh:mm:ss') completed_at,
    TO_CHAR(expires_at, 'yyyy-MM-ddThh:mm:ss') expires_at,
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
