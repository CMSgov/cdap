-- Get all jobs with CMS ID added from acos table
-- This should be run in SANDBOX only!
CREATE OR REPLACE VIEW bcda_sandbox_jobs_with_cms_id AS
SELECT
    jobs.id,
    jobs.aco_id,
    jobs.request_url,
    jobs.status,
    jobs.created_at,
    jobs.updated_at,
    jobs.job_count,
    jobs.transaction_time,
    jobs.benes_attributed_to_aco,
    acos.cms_id,
    job_keys.BenesWithData,
    job_keys.BenesRetrievedPercent
FROM jobs
LEFT JOIN acos ON acos.uuid = jobs.aco_id
LEFT JOIN job_keys on jobs.id = job_keys.job_id;
