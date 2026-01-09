-- ============================================================
-- File: 06_clean_category_tree.sql
-- Project: E-commerce Funnel Optimisation (RetailRocket)
-- Layer: Dimension Cleaning (Category Hierarchy)
-- Purpose: Build analytics-ready category hierarchy
-- ============================================================

USE funnel_project;

-- ============================================================
-- 1. DROP CLEAN TABLE
-- ============================================================

DROP TABLE IF EXISTS category_tree_clean;

-- ============================================================
-- 2. BUILD CLEAN CATEGORY TREE
-- ============================================================

CREATE TABLE category_tree_clean AS
WITH RECURSIVE category_hierarchy AS (

    -- Root categories (no parent or parent = 0 in this dataset)
    SELECT
        c.categoryid,
        c.parentid,
        c.categoryid        AS root_category_id,
        0                   AS category_level
    FROM category_tree_raw c
    WHERE c.parentid IS NULL OR c.parentid = 0

    UNION ALL

    -- Recursive expansion, with max depth guard to prevent infinite loops
    SELECT
        c.categoryid,
        c.parentid,
        ch.root_category_id,
        ch.category_level + 1 AS category_level
    FROM category_tree_raw c
    JOIN category_hierarchy ch
        ON c.parentid = ch.categoryid
    WHERE ch.category_level < 10   -- safety limit
)

SELECT
    categoryid,
    parentid,
    root_category_id,
    category_level
FROM category_hierarchy;

-- ============================================================
-- 3. INDEXES 
-- ============================================================

CREATE INDEX idx_cat_categoryid
    ON category_tree_clean (categoryid);

CREATE INDEX idx_cat_parentid
    ON category_tree_clean (parentid);

CREATE INDEX idx_cat_root
    ON category_tree_clean (root_category_id);

CREATE INDEX idx_cat_level
    ON category_tree_clean (category_level);

-- ============================================================
-- 4. SANITY CHECKS
-- ============================================================

-- Total categories
SELECT COUNT(*) AS total_categories
FROM category_tree_clean;

-- Root categories
SELECT COUNT(*) AS root_categories
FROM category_tree_clean
WHERE category_level = 0;

-- Max depth of tree
SELECT MAX(category_level) AS max_category_depth
FROM category_tree_clean;

-- Categories by level
SELECT
    category_level,
    COUNT(*) AS categories
FROM category_tree_clean
GROUP BY category_level
ORDER BY category_level;

SELECT
    'Category tree cleaned successfully' AS status,
    NOW() AS finished_at;
