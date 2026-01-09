-- ============================================================
-- File:        01_load_raw_data.sql
-- Project:     E-Commerce Funnel Optimisation (RetailRocket)
-- Layer:       Raw Ingestion
-- Purpose:     Deterministically load RetailRocket CSVs into
--              raw tables 
-- ============================================================

USE funnel_project;

SET sql_mode = 'STRICT_ALL_TABLES';


-- ============================================================
-- 1. CLEAR RAW TABLES
-- ============================================================

TRUNCATE TABLE events_raw;
TRUNCATE TABLE item_properties_raw;
TRUNCATE TABLE category_tree_raw;

SELECT 'Raw tables truncated' AS status, NOW() AS ts;


-- ============================================================
-- 2. LOAD EVENTS DATA
-- Expected rows: ~2.7 million
-- CSV columns: event_ts_ms, visitorid, event, itemid, transactionid
-- ============================================================

LOAD DATA LOCAL INFILE
'/Users/rajnishpanwar/Desktop/funnel_optimization_project/data/raw/events.csv'
INTO TABLE events_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(event_ts_ms, visitorid, event, itemid, transactionid);

SELECT COUNT(*) AS events_loaded FROM events_raw;


-- ============================================================
-- 3. LOAD ITEM PROPERTIES (PART 1)
-- CSV columns: event_ts_ms, itemid, property, value
-- ============================================================

LOAD DATA LOCAL INFILE
'/Users/rajnishpanwar/Desktop/funnel_optimization_project/data/raw/item_properties_part1.csv'
INTO TABLE item_properties_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(event_ts_ms, itemid, property, value);


-- ============================================================
-- 4. LOAD ITEM PROPERTIES (PART 2) Same schema as part 1, appended into same table
-- ============================================================

LOAD DATA LOCAL INFILE
'/Users/rajnishpanwar/Desktop/funnel_optimization_project/data/raw/item_properties_part2.csv'
INTO TABLE item_properties_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(event_ts_ms, itemid, property, value);

SELECT COUNT(*) AS item_properties_loaded FROM item_properties_raw;


-- ============================================================
-- 5. LOAD CATEGORY TREE
-- CSV columns:categoryid, parentid
-- ============================================================

LOAD DATA LOCAL INFILE
'/Users/rajnishpanwar/Desktop/funnel_optimization_project/data/raw/category_tree.csv'
INTO TABLE category_tree_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(categoryid, parentid);

SELECT COUNT(*) AS categories_loaded FROM category_tree_raw;


-- ============================================================
-- 6. FINAL COUNTS
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM events_raw)          AS events_raw_count,
    (SELECT COUNT(*) FROM item_properties_raw) AS item_properties_raw_count,
    (SELECT COUNT(*) FROM category_tree_raw)   AS category_tree_raw_count;

SELECT 'Raw ingestion completed successfully' AS status, NOW() AS finished_at;
