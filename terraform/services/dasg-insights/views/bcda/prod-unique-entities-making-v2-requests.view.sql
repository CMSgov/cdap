-- Get total unique, active ACOs that are making v2 requests
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_unique_entities_making_v2_requests AS
select distinct acos.cms_id,
    jobs.request_url
from jobs
    join acos on acos.uuid = jobs.aco_id
    inner join active_acos on acos.cms_id = active_acos.cms_id
where jobs.request_url like '%/v2/%';