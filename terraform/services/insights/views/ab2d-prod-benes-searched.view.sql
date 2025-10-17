CREATE VIEW ab2d_prod_benes_searched AS
    SELECT 
    contract_number,
    job_uuid,
    benes_searched,
    TO_CHAR(created_at, 'yyyy-MM-ddThh:mm:ss') created_at, 
    TO_CHAR(completed_at, 'yyyy-MM-ddThh:mm:ss') completed_at,
    eobs_written,
    time_to_complete,
    data_start_time,
    since,
    fhir_version,
    status,
    contract_number AS "Contract Number", 
    job_uuid AS "Job ID", 
    benes_searched AS "# Bene Searched",
    completed_at AS "Completed At",
    eobs_written AS "# EoBs Written",
    data_start_time AS "Data Start Date (Since Date)",
    fhir_version AS "FHIR Version",
    to_char(time_to_complete, 'HH24:MI:SS') AS "Seconds Run",
    TO_CHAR(created_at, 'yyyy-MM-ddThh:mm:ss') "Job Start Time",
    TO_CHAR(completed_at, 'yyyy-MM-ddThh:mm:ss') "Job Complete Time",
    to_char(time_to_complete, 'HH24:MI:SS') AS sec_run,
    TO_CHAR(created_at, 'yyyy-MM-ddThh:mm:ss') job_start_time,
    TO_CHAR(completed_at, 'yyyy-MM-ddThh:mm:ss') job_complete_time
  FROM (
    SELECT 
      s.contract_number, 
      j.job_uuid, 
      s.benes_searched, 
      j.created_at, 
      j.completed_at, 
      s.eobs_written, 
      j.completed_at - j.created_at as time_to_complete,
      CASE
        WHEN j.since is null
        THEN
          CASE
            WHEN c.attested_on < '2020-01-01'
            THEN '2020-01-01'
            ELSE c.attested_on
          END
        ELSE j.since
      END AS data_start_time,
      j.since,
      j.fhir_version,
      j.status
    FROM job j
    LEFT JOIN event.event_bene_search s ON s.job_id = j.job_uuid
    LEFT JOIN contract_view c ON c.contract_number = j.contract_number
    WHERE j.started_by='PDP') t
    ORDER BY "Job Start Time" DESC;
