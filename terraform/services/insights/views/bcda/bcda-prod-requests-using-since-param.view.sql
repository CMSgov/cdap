CREATE OR REPLACE VIEW bcda_prod_requests_using_since_param AS
select acos.cms_id, jobs.request_url from jobs
join acos on acos.uuid = jobs.aco_id
where jobs.request_url like '%_since%'
and jobs.created_at > DATE(NOW() - interval '1 year');