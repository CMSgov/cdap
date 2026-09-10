-- Onboarded production entities with zero data requests (in acos but no row in jobs).
-- Only non-terminated entities. NO PHI/PII allowed!
-- Tracking: Total onboarded entities with zero data requests
CREATE OR REPLACE VIEW bcda_prod_onboarded_entities_zero_requests AS
SELECT acos.cms_id
FROM acos
WHERE acos.cms_id IS NOT NULL
    AND acos.cms_id !~ '^(A999|V99|E999|TEST|DA999|K999)'
    AND acos.termination_details IS NULL
    AND NOT EXISTS (SELECT 1 FROM jobs WHERE jobs.aco_id = acos.uuid);
