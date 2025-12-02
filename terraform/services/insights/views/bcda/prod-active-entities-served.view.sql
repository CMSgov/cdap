-- Get all active ACOs that have had credentials created, updated, or deleted in the past year
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_active_entities_served AS
select distinct on (acos.cms_id) acos.cms_id
from active_acos acos
    join groups g on g.x_data::json#>>'{"cms_ids",0}' = acos.cms_id
    join systems s on s.g_id = g.id
    join secrets sec on sec.system_id = s.id
where sec.created_at > DATE(NOW() - interval '1 year')
    or sec.updated_at > DATE(NOW() - interval '1 year')
    or sec.deleted_at > DATE(NOW() - interval '1 year');