CREATE VIEW ab2d_prod_contracts_view AS
  SELECT
    contract_number,
    contract_name,
    TO_CHAR(attested_on, 'yyyy-MM-ddThh:mm:ss') attested_on,
    TO_CHAR(created, 'yyyy-MM-ddThh:mm:ss') created,
    TO_CHAR(modified, 'yyyy-MM-ddThh:mm:ss') modified,
    hpms_parent_org_name,
    hpms_org_marketing_name,
    update_mode,
    contract_type,
    CASE 
      WHEN enabled='f' THEN 0
      WHEN enabled='t' THEN 1
    END AS enabled 
  FROM contract_view;
