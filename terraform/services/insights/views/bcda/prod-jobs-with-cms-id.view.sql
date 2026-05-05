-- Get all jobs with CMS ID added from acos table
CREATE OR REPLACE VIEW bcda_prod_jobs_with_cms_id AS
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
    CASE
        WHEN acos.cms_id ~ 'D\d{4}' THEN 'ACO REACH'
        WHEN acos.cms_id ~ 'K\d{4}' THEN 'KCC'
        WHEN acos.cms_id ~ 'C\d{4}' THEN 'KCC'
        WHEN acos.cms_id ~ 'CT\d{6}' THEN 'MD TCoC'
        WHEN acos.cms_id ~ '^A\d{4}' THEN 'SSP'
        WHEN acos.cms_id ~ 'IOTA\d{3}' THEN 'IOTA'
        WHEN acos.cms_id ~ 'GUIDE-\d{5}' THEN 'GUIDE'
        WHEN acos.cms_id ~ 'DA\d{4}' THEN 'CDAC'
        WHEN acos.cms_id ~ 'TEST\d{3}' THEN 'TEST'
        WHEN acos.cms_id ~ 'V\d{3}' THEN 'NGACO'
        WHEN acos.cms_id ~ 'E\d{4}' THEN 'CEC'
        ELSE 'Unknown'
    END AS model_name,
    sq.benes_with_data,
    sq.benes_retrieved_percent
FROM jobs
LEFT JOIN acos ON acos.uuid = jobs.aco_id
JOIN (
	SELECT job_id, SUM(benes_with_data) AS benes_with_data, AVG(benes_retrieved_percent) AS benes_retrieved_percent FROM job_keys
	GROUP BY job_id
) AS sq
ON sq.job_id = jobs.id 
