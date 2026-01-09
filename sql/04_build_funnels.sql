-- ============================================================
-- File:    04_build_funnels.sql
-- Project: E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:   Funnel Construction (Session-level)
-- Purpose: Build session-level conversion funnels with
--          explicit validity and ordering checks.
-- ============================================================

USE funnel_project;


-- ============================================================
-- 1. DROP EXISTING TABLE
-- ============================================================

DROP TABLE IF EXISTS session_funnels;


-- ============================================================
-- 2. BUILD SESSION-LEVEL FUNNEL
-- ============================================================

CREATE TABLE session_funnels AS
WITH stage_times AS (
    SELECT
        s.session_id,
        s.visitorid,
        s.session_start,
        s.session_end,
        s.session_duration_seconds,

        -- Funnel stage presence
        MAX(e.event_type = 'view')         AS has_view,
        MAX(e.event_type = 'addtocart')    AS has_addtocart,
        MAX(e.event_type = 'transaction')  AS has_transaction,

        -- First occurrence timestamps
        MIN(CASE WHEN e.event_type = 'view' THEN e.event_datetime END)          AS first_view_time,
        MIN(CASE WHEN e.event_type = 'addtocart' THEN e.event_datetime END)     AS first_addtocart_time,
        MIN(CASE WHEN e.event_type = 'transaction' THEN e.event_datetime END)  AS first_transaction_time
    FROM sessions s
    LEFT JOIN events_sessionized e
        ON s.session_id = e.session_id
    GROUP BY
        s.session_id,
        s.visitorid,
        s.session_start,
        s.session_end,
        s.session_duration_seconds
)

SELECT
    session_id,
    visitorid,
    session_start,
    session_end,
    session_duration_seconds,

    has_view,
    has_addtocart,
    has_transaction,

    first_view_time,
    first_addtocart_time,
    first_transaction_time,

    -- Funnel invalid reason (NULL means valid)
    CASE
        WHEN has_transaction = 1 AND first_view_time IS NULL
            THEN 'TXN_WITHOUT_VIEW'
        WHEN has_transaction = 1 AND first_addtocart_time IS NULL
            THEN 'TXN_WITHOUT_ADDTOCART'
        WHEN has_transaction = 1 AND first_transaction_time < first_addtocart_time
            THEN 'TXN_BEFORE_ADDTOCART'
        WHEN has_addtocart = 1 AND first_view_time IS NULL
            THEN 'ADDTOCART_WITHOUT_VIEW'
        WHEN has_addtocart = 1 AND first_addtocart_time < first_view_time
            THEN 'ADDTOCART_BEFORE_VIEW'
        ELSE NULL
    END AS invalid_reason,

    CASE
        WHEN
            (
                has_transaction = 1 AND (
                       first_view_time IS NULL
                    OR first_addtocart_time IS NULL
                    OR first_transaction_time < first_addtocart_time
                    OR first_addtocart_time < first_view_time
                )
            )
            OR
            (
                has_addtocart = 1 AND (
                       first_view_time IS NULL
                    OR first_addtocart_time < first_view_time
                )
            )
        THEN 0
        ELSE 1
    END AS valid_funnel

FROM stage_times;


-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX idx_funnel_session ON session_funnels (session_id);
CREATE INDEX idx_funnel_visitor ON session_funnels (visitorid);
CREATE INDEX idx_funnel_valid   ON session_funnels (valid_funnel);


-- ============================================================
-- 4. FUNNEL METRICS
-- ============================================================

-- Total sessions
SELECT COUNT(*) AS total_sessions
FROM session_funnels;

-- Stage reach counts (VALID funnels only)
SELECT
    SUM(has_view)        AS sessions_with_view,
    SUM(has_addtocart)   AS sessions_with_addtocart,
    SUM(has_transaction) AS sessions_with_transaction
FROM session_funnels
WHERE valid_funnel = 1;

-- Conversion rates (VALID funnels only; defensive against division by zero)
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

SELECT 'Funnel construction completed successfully' AS status, NOW() AS finished_at;
