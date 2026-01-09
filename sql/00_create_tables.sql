-- ============================================================
-- File:        00_create_tables.sql
-- Project:     E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:       Raw Data Layer
-- Purpose:     Create raw tables that mirror source CSVs 
-- ============================================================


-- ============================================================
-- 1. DATABASE INITIALISATION
-- Reset database to ensure deterministic, reproducible runs.
-- ============================================================

DROP DATABASE IF EXISTS funnel_project;

CREATE DATABASE funnel_project
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE funnel_project;

SELECT 'Database funnel_project created successfully' AS status;


-- ============================================================
-- 2. RAW EVENTS TABLE
-- Stores the raw RetailRocket event stream exactly as ingested.
-- ============================================================

DROP TABLE IF EXISTS events_raw;

CREATE TABLE events_raw (
    event_ts_ms     BIGINT NOT NULL COMMENT 'Unix timestamp in milliseconds (UTC)',
    visitorid       INT NOT NULL COMMENT 'Unique visitor identifier',
    event           VARCHAR(20) NOT NULL COMMENT 'Raw event type (view, addtocart, transaction)',
    itemid          INT DEFAULT NULL COMMENT 'Item ID (nullable for non-item events)',
    transactionid   INT DEFAULT NULL COMMENT 'Transaction ID (only for purchases)',
    load_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Ingestion timestamp',

    INDEX idx_visitor_time (visitorid, event_ts_ms),
    INDEX idx_event (event),
    INDEX idx_itemid (itemid)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COMMENT='Raw RetailRocket event stream (no transformations)';


-- ============================================================
-- 3. RAW ITEM PROPERTIES TABLE
-- Long-format key-value table for item metadata.
-- RetailRocket provides this data split across two files.
-- ============================================================

DROP TABLE IF EXISTS item_properties_raw;

CREATE TABLE item_properties_raw (
    event_ts_ms     BIGINT NOT NULL COMMENT 'Unix timestamp in milliseconds (UTC)',
    itemid          INT NOT NULL COMMENT 'Item ID',
    property        VARCHAR(100) NOT NULL COMMENT 'Property name',
    value           TEXT COMMENT 'Property value (string encoded)',
    load_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Ingestion timestamp',

    INDEX idx_item_property (itemid, property)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COMMENT='Raw item property key-value data';


-- ============================================================
-- 4. CATEGORY TREE TABLE
-- Static hierarchy mapping items to categories.
-- ============================================================

DROP TABLE IF EXISTS category_tree_raw;

CREATE TABLE category_tree_raw (
    categoryid      INT NOT NULL COMMENT 'Category ID',
    parentid        INT DEFAULT NULL COMMENT 'Parent category ID (NULL for root)',
    load_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Ingestion timestamp',

    PRIMARY KEY (categoryid),
    INDEX idx_parentid (parentid)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COMMENT='Category hierarchy structure';


-- ============================================================
-- 5. SCHEMA VALIDATION
-- Quick sanity check that all raw tables exist as expected.
-- ============================================================

SELECT 
    TABLE_NAME AS table_name,
    ENGINE AS engine,
    TABLE_COLLATION AS collation,
    TABLE_COMMENT AS description
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'funnel_project'
ORDER BY TABLE_NAME;

SELECT 'Raw schema created successfully. Ready for CSV loading.' AS status;
