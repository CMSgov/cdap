-- Get PRODUCTION job request calls by week (total, V1, V2, and V3)
-- Also includes total cancelled calls and cancelled calls by version
-- Weeks run Sunday to Saturday
CREATE OR REPLACE VIEW bcda_prod_job_request_calls_weekly AS
SELECT
    week_start,
    week_end,
    COUNT(*) AS total_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v1/%') AS v1_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v2/%') AS v2_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v3/%') AS v3_api_calls,
    COUNT(*) FILTER (WHERE jobs.status IN ('Cancelled', 'CancelledExpired')) AS total_cancelled_calls,
    COUNT(*) FILTER (WHERE jobs.status IN ('Cancelled', 'CancelledExpired') AND jobs.request_url LIKE '%/v1/%') AS v1_cancelled_calls,
    COUNT(*) FILTER (WHERE jobs.status IN ('Cancelled', 'CancelledExpired') AND jobs.request_url LIKE '%/v2/%') AS v2_cancelled_calls,
    COUNT(*) FILTER (WHERE jobs.status IN ('Cancelled', 'CancelledExpired') AND jobs.request_url LIKE '%/v3/%') AS v3_cancelled_calls
FROM (
    SELECT
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') AS week_start,
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') + INTERVAL '6 days' AS week_end,
        jobs.request_url,
        jobs.status
    FROM jobs
    LEFT JOIN acos ON acos.uuid = jobs.aco_id
    WHERE acos.cms_id !~ '^(A999|V99|E999|TEST|DA999)'
) jobs
GROUP BY week_start, week_end
ORDER BY week_start DESC;
