-- Get all jobs with CMS ID added from acos table
-- This should be run in SANDBOX only!
CREATE OR REPLACE VIEW bcda_jobs_with_cms_id AS
SELECT
    jobs.*,
    acos.cms_id
FROM jobs
LEFT JOIN acos ON acos.uuid = jobs.aco_id;