CREATE OR REPLACE VIEW bcda_prod_beneficiaries_attributed_to_active_entities AS
select sub.cms_id, sub.latest_cclf_file, cf.timestamp, COUNT(cb.id) as total_benes from (
	SELECT acos.cms_id as cms_id, MAX(cf.id) as latest_cclf_file FROM active_acos acos
	JOIN cclf_files cf ON acos.cms_id = cf.aco_cms_id
	group by acos.cms_id
	order by acos.cms_id asc
) sub
join cclf_beneficiaries cb on cb.file_id = sub.latest_cclf_file
join cclf_files cf on cf.id = sub.latest_cclf_file
where cf.timestamp > DATE(NOW() - interval '1 year')
group by sub.cms_id, sub.latest_cclf_file, cf.timestamp;