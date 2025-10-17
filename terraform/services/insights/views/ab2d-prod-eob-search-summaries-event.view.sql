CREATE VIEW ab2d_prod_eob_search_summaries_event AS
  SELECT
    jv.week_start,
    jv.week_end,
    jv.contract_number,
    jv.job_uuid,
    TO_CHAR(jv.created_at, 'yyyy-MM-ddThh:mm:ss') created_at,
    TO_CHAR(jv.completed_at, 'yyyy-MM-ddThh:mm:ss') completed_at,
    jv.since,
    bs.benes_searched,
    TO_CHAR(jv.completed_at - jv.created_at,'HH24:MI:SS') time_to_complete
  FROM ab2d.job_view AS jv
  LEFT JOIN event.event_bene_search AS bs
  ON bs.job_id = jv.job_uuid
  ORDER BY week_start DESC;
