-- Runout requests made in PROD
-- Tracking: Number of calls made for prior year runout. Removed time limit and added creation date for runout view.
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_requests_for_runout_data AS
select acos.cms_id,
    jobs.request_url,
    jobs.created_at
from jobs
    join acos on acos.uuid = jobs.aco_id
where jobs.request_url like '%/runout/%';