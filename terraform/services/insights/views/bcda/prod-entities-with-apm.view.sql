-- All production entities from acos with CMS ID, alternative payment model, and termination_date.
-- NO PHI/PII allowed! Consumer may filter by termination_date IS NULL for active only.
-- Model names from bcda-app/conf/configs/prod.yml (match order: more specific first).
CREATE OR REPLACE VIEW bcda_prod_entities_with_apm AS
SELECT acos.cms_id,
    CASE
        WHEN acos.cms_id ~ '^A\d{4}$' THEN 'SSP'
        WHEN acos.cms_id ~ '^DA\d{4}$' THEN 'CDAC'
        WHEN acos.cms_id ~ '^D\d{4}$' THEN 'DC'
        WHEN acos.cms_id ~ '^C\d{4}$' THEN 'CKCC'
        WHEN acos.cms_id ~ '^K\d{4}$' THEN 'KCF'
        WHEN acos.cms_id ~ '^E\d{4}$' THEN 'CEC'
        WHEN acos.cms_id ~ '^V\d{3}$' THEN 'NGACO'
        WHEN acos.cms_id ~ '^TEST\d{3}$' THEN 'TEST'
        WHEN acos.cms_id ~ '^CT\d{6}$' THEN 'MDTCOC'
        WHEN acos.cms_id ~ '^GUIDE-\d{5}$' THEN 'GUIDE'
        WHEN acos.cms_id ~ '^IOTA\d{3}$' THEN 'IOTA'
        ELSE 'Other'
    END AS alternative_payment_model,
    (acos.termination_details->>'TerminationDate')::timestamptz AS termination_date
FROM acos
WHERE acos.cms_id IS NOT NULL;