CREATE VIEW ab2d_prod_benes_weekly AS
  SELECT 
    week_start,
    week_end,
    SUM(t.total_benes) AS total_benes
  FROM (
    SELECT 
      jv.contract_number,
      DATE_TRUNC('day', jv.week_start) AS week_start,
      DATE_TRUNC('day', jv.week_end) AS week_end,
      MAX(bs.benes_searched) AS total_benes
    FROM ab2d.job_view AS jv
    LEFT JOIN event.event_bene_search AS bs ON bs.job_id = jv.job_uuid
    WHERE jv.status = 'SUCCESSFUL'
    GROUP BY jv.contract_number, jv.week_start, jv.week_end) t
    GROUP BY t.week_start, t.week_end
    ORDER BY week_start DESC;
