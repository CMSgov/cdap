-- Get SANDBOX API calls by week (total, V1, V2, and V3)
-- Weeks run Sunday to Saturday
-- This should be run in SANDBOX only!
CREATE OR REPLACE VIEW bcda_sandbox_api_calls_weekly AS
SELECT
    week_start,
    week_end,
    cms_id,
    COUNT(*) AS total_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v1/%') AS v1_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v2/%') AS v2_api_calls,
    COUNT(*) FILTER (WHERE jobs.request_url LIKE '%/v3/%') AS v3_api_calls
FROM (
    SELECT
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') AS week_start,
        DATE(jobs.created_at) - (EXTRACT(DOW FROM jobs.created_at)::int * INTERVAL '1 day') + INTERVAL '6 days' AS week_end,
        acos.cms_id,
        jobs.request_url
    FROM jobs
    JOIN acos ON acos.uuid = jobs.aco_id
    WHERE jobs.aco_id IN (
        '48351751-8d6a-4c8e-ae0c-7f249cf356ea',
        -- Basic XSmall ACO
        '467bb940-7a40-4201-8aee-53d6015362fe',
        -- Basic Small ACO
        '09505976-871f-4a65-b0b0-42314181551e',
        -- Basic Medium ACO
        '16993e50-c24f-4992-9212-4c53f0590d67',
        -- Basic Large ACO
        'db461333-663a-4a36-b18d-16c54368a3a2',
        -- Basic XLarge ACO
        '3bbc86c4-975f-4e43-b063-f6ad65d374d3',
        -- Basic Mega ACO
        '725676ba-4cce-4989-b5da-3ff56ad9cce7',
        -- Adv Small ACO
        '638db6b9-16ba-4a84-8a2d-c77957645ea1',
        -- Adv Large ACO
        '63fe13f0-20bd-4822-ab61-2f7ec80635c2',
        -- PACA Small ACO
        '44f78e2b-5247-4557-b41e-4d2d66babc0d' -- PACA Large ACO
    )
) jobs
GROUP BY week_start, week_end, cms_id
ORDER BY week_start DESC, cms_id;