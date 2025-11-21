CREATE VIEW bcda_prod_unique_entities_making_v2_requests AS
select distinct acos.cms_id, jobs.request_url from jobs
join acos on acos.uuid = jobs.aco_id
inner join bcda_prod_active_acos on acos.cms_id = bcda_prod_active_acos.cms_id
where jobs.request_url like '%/v2/%';