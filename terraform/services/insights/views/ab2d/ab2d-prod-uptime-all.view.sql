CREATE VIEW ab2d_prod_uptime_all AS
  WITH 
    ranked AS (
      SELECT 
        service,
        state_type,
        event_description,
        time_of_event,
        SUM(
          CASE
            WHEN prevDate IS NULL THEN 1
            WHEN EXTRACT(epoch FROM (time_of_event - prevDate)) >= 600 THEN 1
            ELSE 0
          END
        ) OVER (ORDER BY time_of_event) AS Rnk
      FROM (
        SELECT 
          service,
          state_type,
          event_description,
          time_of_event,
          LAG(time_of_event) OVER (ORDER BY time_of_event) AS prevDate
        FROM event.event_metrics
      ) q1
    ),
    rankings AS (
      SELECT 
        service,
        time_of_event,
        state_type,
        event_description,
        DENSE_RANK() OVER (PARTITION BY service ORDER BY time_of_event) 
          - DENSE_RANK() OVER (PARTITION BY service, Rnk ORDER BY time_of_event)
          AS sequence_grouping
      FROM ranked
      WHERE state_type = 'CONTINUE'
      ORDER BY time_of_event ASC
    ),
    data AS (
      SELECT
        service,
        event_description,
        MIN(time_of_event) AS start_date,
        MAX(time_of_event)AS end_date,
        MAX(time_of_event) - MIN(time_of_event) AS duration
      FROM rankings
      GROUP BY 
        service,
        sequence_grouping,
        event_description
      UNION ALL
      SELECT 
        service,
        event_description,
        start_date,
        end_date,
        end_date - start_date AS duration
      FROM (
        SELECT 
          service,
          event_description,
          time_of_event as start_date,
          (
            SELECT time_of_event
            FROM event.event_metrics b
            WHERE b.service = a.service
            AND state_type = 'END'
            AND b.time_of_event >= a.time_of_event
            ORDER BY b.time_of_event
            LIMIT 1
          ) AS end_date
        FROM 
          event.event_metrics a
        WHERE state_type = 'START'
        GROUP BY 
          service,
          state_type,
          event_description,
          time_of_event
        ORDER BY a.time_of_event
      ) strstp
    ),
    hours AS (
      SELECT 
        d.hour
      FROM generate_series(now() - interval '30 day', now(), interval '1 hour') d(hour)),
      MATCHES AS (
        SELECT
                m.hour,
                'uptime' as uptime,
                COUNT(*) AS ct,
                event_description,
                service FROM hours m
                CROSS JOIN (
                  SELECT DISTINCT start_date 
                  FROM data
                ) AS i
                CROSS JOIN LATERAL (
                  SELECT 
                    service,
                    event_description
                  FROM 
                    data a
                  WHERE a.start_date < m.hour + interval '1 hour'
                  AND (a.end_date >= m.hour OR a.end_date IS NULL)
                  ORDER BY a.end_date DESC
                  LIMIT 1
                ) a
                GROUP BY 
                  m.hour,
                  a.service,
                  event_description
                ORDER BY 
                  m.hour, 
                  a.service, 
                  event_description
                ),
                COMBINED AS (
                  SELECT 
                    m.hour,
                    uptime,
                    0 AS up,
                    event_description
                  FROM matches m
                  UNION
                  SELECT
                    h.hour,
                    'uptime' AS uptime,
                    1 as up,
                    '' as event_description
                  FROM hours h
                  ORDER BY hour
                )
                SELECT
                  hour,
                  uptime,
                  up, 
                  event_description
                FROM (
                  SELECT 
                    *,
                    LAG(up) OVER (PARTITION BY hour ORDER BY hour, up) AS prev_year
                  FROM combined
                  GROUP BY 
                    hour, 
                    uptime,
                    up,
                    event_description
                    ) comp
                  WHERE comp.prev_year IS NULL;
