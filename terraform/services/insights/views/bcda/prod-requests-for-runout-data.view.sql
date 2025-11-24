CREATE OR REPLACE VIEW bcda_prod_requests_for_runout_data AS
select acos.cms_id,
    jobs.request_url
from jobs
    join acos on acos.uuid = jobs.aco_id
where jobs.request_url like '%/runout/%'
    and jobs.created_at > DATE(NOW() - interval '1 year');