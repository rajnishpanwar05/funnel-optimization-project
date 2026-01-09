-- =============================================================================
-- File:    03_sessionization.sql
-- Project: E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:   Behavioral Modeling / Sessionization
-- Purpose: Identify user sessions based on inactivity gaps and
--          construct event-level sessionized data.
-- =============================================================================

USE funnel_project;

-- =============================================================================
-- 1. CONFIGURATION
-- =============================================================================

SET @session_timeout_minutes := 30;
SET @session_timeout_seconds := @session_timeout_minutes * 60;


-- =============================================================================
-- 2. DROP EXISTING OBJECTS
-- =============================================================================

DROP TABLE IF EXISTS events_sessionized;
DROP TABLE IF EXISTS sessions;


-- =============================================================================
-- 3. SESSIONIZE EVENTS (EVENT-LEVEL, NO AGGREGATION)
-- =============================================================================

CREATE TABLE events_sessionized AS
WITH ordered_events AS (
    SELECT
        event_id,
        visitorid,
        event_ts_ms,
        event_datetime,
        event_type,
        itemid,
        transactionid,

        LAG(event_datetime) OVER (
            PARTITION BY visitorid
            ORDER BY event_datetime, event_id
        ) AS prev_event_datetime
    FROM events_clean
    WHERE visitorid IS NOT NULL
      AND event_datetime IS NOT NULL
      AND event_type IS NOT NULL
),

session_flags AS (
    SELECT
        *,
        CASE
            WHEN prev_event_datetime IS NULL THEN 1
            WHEN TIMESTAMPDIFF(
                    SECOND,
                    prev_event_datetime,
                    event_datetime
                 ) > @session_timeout_seconds
            THEN 1
            ELSE 0
        END AS is_new_session
    FROM ordered_events
),

session_numbers AS (
    SELECT
        *,
        SUM(is_new_session) OVER (
            PARTITION BY visitorid
            ORDER BY event_datetime, event_id
            ROWS UNBOUNDED PRECEDING
        ) AS session_seq
    FROM session_flags
),

session_events AS (
    SELECT
        *,
        CONCAT(visitorid, '_', session_seq) AS session_id,
        ROW_NUMBER() OVER (
            PARTITION BY visitorid, session_seq
            ORDER BY event_datetime, event_id
        ) AS event_order_in_session
    FROM session_numbers
)

SELECT
    event_id,
    visitorid,
    event_ts_ms,
    event_datetime,
    event_type,
    itemid,
    transactionid,
    session_id,
    session_seq,
    event_order_in_session
FROM session_events;


-- =============================================================================
-- 4. INDEXING (EVENT-LEVEL)
-- =============================================================================

CREATE INDEX idx_es_visitor_time
    ON events_sessionized (visitorid, event_datetime);

CREATE INDEX idx_es_session
    ON events_sessionized (session_id);

CREATE INDEX idx_es_session_order
    ON events_sessionized (session_id, event_order_in_session);

CREATE INDEX idx_es_event_type
    ON events_sessionized (event_type);


-- =============================================================================
-- 5. SESSION-LEVEL TABLE (DIAGNOSTIC / REPORTING ONLY)
-- =============================================================================
-- IMPORTANT:
-- This table MUST NOT be used for predictive modeling.
-- It contains full-session aggregates including outcome-driven signals.
-- =============================================================================

CREATE TABLE sessions AS
SELECT
    session_id,
    visitorid,

    MIN(event_datetime) AS session_start,
    MAX(event_datetime) AS session_end,

    TIMESTAMPDIFF(
        SECOND,
        MIN(event_datetime),
        MAX(event_datetime)
    ) AS session_duration_seconds,

    COUNT(*) AS total_events,

    SUM(event_type = 'view')         AS views,
    SUM(event_type = 'addtocart')    AS addtocarts,
    SUM(event_type = 'transaction')  AS transactions,

    MAX(event_type = 'transaction')  AS has_transaction
FROM events_sessionized
GROUP BY session_id, visitorid;


-- =============================================================================
-- 6. SESSION TABLE INDEXES
-- =============================================================================

CREATE INDEX idx_sessions_visitor
    ON sessions (visitorid);

CREATE INDEX idx_sessions_start
    ON sessions (session_start);

CREATE INDEX idx_sessions_txn
    ON sessions (has_transaction);


-- =============================================================================
-- 7. SANITY CHECKS
-- =============================================================================

-- Total number of sessions
SELECT COUNT(*) AS total_sessions FROM sessions;

-- Average session duration (minutes)
SELECT
    ROUND(AVG(session_duration_seconds) / 60, 2) AS avg_session_minutes
FROM sessions;

-- Session-level conversion rate (diagnostic only)
SELECT
    ROUND(
        SUM(has_transaction) / COUNT(*) * 100,
        2
    ) AS session_conversion_rate_pct
FROM sessions;
