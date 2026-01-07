-- Get PRODUCTION API calls by week (total, V1, V2, and V3)
-- Weeks run Sunday to Saturday
CREATE OR REPLACE VIEW bcda_prod_api_calls_weekly AS
SELECT
    week_start,
    week_end,
    COUNT(*) AS total_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v1/%') AS v1_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v2/%') AS v2_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v3/%') AS v3_api_calls
FROM (
    SELECT
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') AS week_start,
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') + INTERVAL '6 days' AS week_end,
        jobs.request_url
    FROM jobs
) jobs
GROUP BY week_start, week_end
ORDER BY week_start DESC;
