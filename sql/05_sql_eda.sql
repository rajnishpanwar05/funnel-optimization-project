-- ============================================================
-- File:    05_sql_eda.sql
-- Project: E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:   SQL EDA / Business Validation
-- Purpose:
--   • Validate session and funnel metrics
--   • Lock canonical KPIs
--   • Provide trusted aggregates for Python EDA
-- ============================================================

USE funnel_project;


-- ============================================================
-- 1. DATASET OVERVIEW (SESSION-LEVEL)
-- ============================================================

SELECT
    COUNT(*)                                    AS total_sessions,
    COUNT(DISTINCT visitorid)                   AS unique_visitors,
    ROUND(AVG(session_duration_seconds) / 60, 2) AS avg_session_minutes,
    MIN(session_start)                          AS first_session,
    MAX(session_start)                          AS last_session
FROM sessions;

-- Sessions per day (distribution sanity check)
SELECT
    DATE(session_start) AS session_date,
    COUNT(*)            AS sessions
FROM sessions
GROUP BY DATE(session_start)
ORDER BY session_date;


-- ============================================================
-- 2. FUNNEL COVERAGE (TOTAL vs VALID)
-- ============================================================

SELECT
    COUNT(*) AS total_sessions,
    SUM(valid_funnel = 1) AS valid_sessions,
    SUM(valid_funnel = 0) AS invalid_sessions,
    ROUND(SUM(valid_funnel = 1) / COUNT(*) * 100, 2) AS pct_valid_sessions
FROM session_funnels;

-- Invalid funnel reason distribution (debug + credibility)
SELECT
    COALESCE(invalid_reason, 'VALID') AS funnel_status,
    COUNT(*) AS sessions,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_sessions
FROM session_funnels
GROUP BY COALESCE(invalid_reason, 'VALID')
ORDER BY sessions DESC;


-- ============================================================
-- 3. FUNNEL STAGE COUNTS (VALID FUNNELS ONLY)
-- ============================================================

SELECT
    COUNT(*)             AS valid_sessions,
    SUM(has_view)        AS sessions_with_view,
    SUM(has_addtocart)   AS sessions_with_addtocart,
    SUM(has_transaction) AS sessions_with_transaction
FROM session_funnels
WHERE valid_funnel = 1;


-- ============================================================
-- 4. FUNNEL CONVERSION RATES (VALID FUNNELS ONLY)
-- ============================================================

SELECT
    ROUND(
        SUM(has_addtocart) / NULLIF(SUM(has_view), 0) * 100,
        2
    ) AS view_to_cart_pct,

    ROUND(
        SUM(has_transaction) / NULLIF(SUM(has_addtocart), 0) * 100,
        2
    ) AS cart_to_transaction_pct,

    ROUND(
        SUM(has_transaction) / COUNT(*) * 100,
        2
    ) AS overall_session_conversion_pct
FROM session_funnels
WHERE valid_funnel = 1;


-- ============================================================
-- 5. FUNNEL DROP-OFF ANALYSIS (VALID FUNNELS ONLY)
-- ============================================================

SELECT
    CASE
        WHEN has_view = 1 AND has_addtocart = 0 THEN 'Dropped after view'
        WHEN has_addtocart = 1 AND has_transaction = 0 THEN 'Dropped after addtocart'
        WHEN has_transaction = 1 THEN 'Converted'
        ELSE 'No meaningful activity' -- edge cases within valid sessions
    END AS funnel_outcome,
    COUNT(*) AS sessions,
    ROUND(
        COUNT(*) / SUM(COUNT(*)) OVER () * 100,
        2
    ) AS pct_of_sessions
FROM session_funnels
WHERE valid_funnel = 1
GROUP BY funnel_outcome
ORDER BY sessions DESC;


-- ============================================================
-- 6. SESSION BEHAVIOUR VS CONVERSION (VALID FUNNELS ONLY)
-- ============================================================

-- Average session duration by conversion outcome
SELECT
    has_transaction,
    ROUND(AVG(session_duration_seconds) / 60, 2) AS avg_session_minutes
    -- Median duration computed later in Python
FROM session_funnels
WHERE valid_funnel = 1
GROUP BY has_transaction;

-- Average number of events per session by outcome
SELECT
    f.has_transaction,
    ROUND(AVG(s.total_events), 2) AS avg_events_per_session
FROM session_funnels f
JOIN sessions s
    ON f.session_id = s.session_id
WHERE f.valid_funnel = 1
GROUP BY f.has_transaction;


-- ============================================================
-- 7. TIME-TO-CONVERT ANALYSIS (VALID FUNNELS ONLY)
-- Measures delay from first view to first transaction.
-- ============================================================

SELECT
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                SECOND,
                first_view_time,
                first_transaction_time
            )
        ) / 60,
        2
    ) AS avg_minutes_to_convert
    -- Median time-to-convert computed in Python
FROM session_funnels
WHERE valid_funnel = 1
  AND has_transaction = 1
  AND first_view_time IS NOT NULL
  AND first_transaction_time IS NOT NULL;


-- ============================================================
-- 8. KPI LOCK (SINGLE SOURCE OF TRUTH FOR PYTHON VALIDATION)
-- ============================================================

SELECT
    COUNT(*) AS total_sessions,
    SUM(valid_funnel = 1) AS valid_sessions,

    ROUND(
        SUM(CASE WHEN valid_funnel = 1 THEN has_transaction ELSE 0 END)
        / NULLIF(SUM(valid_funnel = 1), 0) * 100,
        2
    ) AS valid_session_conversion_pct,

    ROUND(
        SUM(CASE WHEN valid_funnel = 1 THEN has_addtocart ELSE 0 END)
        / NULLIF(SUM(CASE WHEN valid_funnel = 1 THEN has_view ELSE 0 END), 0) * 100,
        2
    ) AS view_to_cart_pct_valid,

    ROUND(
        SUM(CASE WHEN valid_funnel = 1 THEN has_transaction ELSE 0 END)
        / NULLIF(SUM(CASE WHEN valid_funnel = 1 THEN has_addtocart ELSE 0 END), 0) * 100,
        2
    ) AS cart_to_transaction_pct_valid
FROM session_funnels;


-- ============================================================
-- 9. SANITY CHECKS & EDGE CASES
-- ============================================================

-- Transactions without any view (should be near zero)
SELECT COUNT(*) AS transactions_without_view
FROM session_funnels
WHERE valid_funnel = 1
  AND has_transaction = 1
  AND has_view = 0;

-- Sessions with multiple transactions
SELECT
    COUNT(*) AS sessions_with_multiple_transactions
FROM sessions
WHERE transactions > 1;

-- Extremely long sessions (> 4 hours)
SELECT
    COUNT(*) AS very_long_sessions
FROM sessions
WHERE session_duration_seconds > 4 * 60 * 60;
