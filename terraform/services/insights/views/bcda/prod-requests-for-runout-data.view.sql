-- Runout requests made in PROD
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_requests_for_runout_data AS
select acos.cms_id,
    jobs.request_url,
    jobs.created_at
from jobs
    join acos on acos.uuid = jobs.aco_id
where jobs.request_url like '%/runout/%';