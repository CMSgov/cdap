CREATE VIEW ab2d_prod_job_view AS
  SELECT
    id,
    job_uuid,
    TO_CHAR(created_at, 'yyyy-MM-ddThh:mm:ss') created_at,
    TO_CHAR(completed_at, 'yyyy-MM-ddThh:mm:ss') completed_at,
    TO_CHAR(expires_at, 'yyyy-MM-ddThh:mm:ss') expires_at,
    resource_types,
    status,
    request_url,
    output_format,
    since,
    TO_CHAR(until, 'yyyy-MM-ddThh:mm:ss') until,
    fhir_version,
    year_week,
    week_start,
    week_end,
    organization,
    contract_number,
    contract_name,
    contract_type
  FROM job_view;
