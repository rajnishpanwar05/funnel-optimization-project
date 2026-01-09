-- ============================================================
-- File:        02_clean_events.sql
-- Project:     E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:       Clean / Conformed Events
-- Purpose:     Convert raw events into a typed, analytics-ready
--              event table used by all downstream logic.
-- ============================================================

USE funnel_project;


-- ============================================================
-- 1. CLEAN EVENTS TABLE
-- ============================================================

DROP TABLE IF EXISTS events_clean;

CREATE TABLE events_clean (
    event_id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    visitorid       INT NOT NULL,
    event_ts_ms     BIGINT NOT NULL COMMENT 'Unix timestamp in milliseconds (UTC)',
    event_datetime  DATETIME NOT NULL COMMENT 'UTC datetime derived from Unix timestamp',
    event_type      ENUM('view','addtocart','transaction') NOT NULL,
    itemid          INT NULL,
    transactionid   INT NULL,
    load_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Transformation timestamp',

    CHECK (event_ts_ms > 0)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COMMENT='Cleaned, typed, analytics-ready event stream';


-- ============================================================
-- 2. INSERT CLEANED EVENTS
-- Transformations applied:
-- - Timestamp conversion (ms → datetime)
-- - Event type normalization
-- - Filtering to valid event types only
-- ============================================================

INSERT INTO events_clean (
    visitorid,
    event_ts_ms,
    event_datetime,
    event_type,
    itemid,
    transactionid
)
SELECT
    visitorid,
    event_ts_ms,
    FROM_UNIXTIME(event_ts_ms / 1000),
    LOWER(event),
    itemid,
    transactionid
FROM events_raw
WHERE LOWER(event) IN ('view','addtocart','transaction');


-- ============================================================
-- 3. INDEXES FOR DOWNSTREAM PERFORMANCE
-- Optimized for sessionisation, funnels, and joins
-- ============================================================

CREATE INDEX idx_events_clean_visitor_time
    ON events_clean (visitorid, event_datetime);

CREATE INDEX idx_events_clean_event_type
    ON events_clean (event_type);

CREATE INDEX idx_events_clean_item
    ON events_clean (itemid);

CREATE INDEX idx_events_clean_transaction
    ON events_clean (transactionid);


-- ============================================================
-- 4. BASIC DATA VALIDATION
-- ============================================================

-- Row count comparison
SELECT
    (SELECT COUNT(*) FROM events_raw)   AS raw_event_rows,
    (SELECT COUNT(*) FROM events_clean) AS clean_event_rows;

-- Event distribution check
SELECT
    event_type,
    COUNT(*) AS event_count
FROM events_clean
GROUP BY event_type
ORDER BY event_count DESC;

-- Time coverage check
SELECT
    MIN(event_datetime) AS first_event,
    MAX(event_datetime) AS last_event
FROM events_clean;
