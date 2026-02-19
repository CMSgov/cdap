-- Number of days from ACO onboarding (acos.created_at) to first job request.
-- Only acos with at least one job are included
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_days_to_first_request AS
SELECT acos.cms_id, acos.created_at AS onboarding_date,
    MIN(jobs.created_at) AS first_job_date,
    (MIN(jobs.created_at)::date - acos.created_at::date) AS days_to_first_request
FROM acos
    INNER JOIN jobs ON jobs.aco_id = acos.uuid
WHERE acos.cms_id IS NOT NULL
GROUP BY acos.cms_id,
    acos.created_at;