CREATE VIEW ab2d_prod_coverage_counts AS
  SELECT
    p.contract_number,
    MAX(
      CASE
        WHEN p.service = 'AB2D' 
        THEN p.count
      END
    ) AS AB2D,
    MAX(
      CASE
        WHEN p.service = 'HPMS' 
        THEN p.count
      END
    ) AS HPMS,
    MAX(
      CASE
        WHEN p.service = 'BFD'
        THEN p.count
      END
    ) AS BFD,
    year, 
    month
  FROM (
    SELECT DISTINCT ON (
      contract_number,
      service,
      year,
      month
    ) contract_number,
    service,
    create_at,
    count,
    year,
    month
    FROM lambda.coverage_counts
    ORDER BY 
      contract_number,
      service,
      year,
      month,
      create_at desc) p
    GROUP BY 
      contract_number,
      year,
      month;
