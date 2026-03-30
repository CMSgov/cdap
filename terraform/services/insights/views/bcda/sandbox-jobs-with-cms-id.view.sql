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
    sq.benes_with_data,
    sq.benes_retrieved_percent
FROM jobs
LEFT JOIN acos ON acos.uuid = jobs.aco_id
JOIN (
	SELECT job_id, SUM(benes_with_data) AS benes_with_data, AVG(benes_retrieved_percent) AS benes_retrieved_percent FROM job_keys
	GROUP BY job_id
) AS sq
ON sq.job_id = jobs.id 

