CREATE VIEW ab2d_prod_contracts_one_job_minimum AS
  SELECT 
    COUNT(DISTINCT c.contract_number) AS "Contracts, at least 1 Job"
    FROM ab2d.contract_view c
    INNER JOIN ab2d.job_view j ON j.contract_number = c.contract_number
    WHERE c.contract_number NOT LIKE 'Z%';
