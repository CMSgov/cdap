-- Get all jobs with CMS ID added from acos table
CREATE OR REPLACE VIEW bcda_prod_jobs_with_cms_id AS
SELECT
    jobs.*,
    acos.cms_id
FROM jobs
LEFT JOIN acos ON acos.uuid = jobs.aco_id;