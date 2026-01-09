# Data Dictionary

## Overview
This document defines all tables, columns, and business logic used in the Funnel Optimization project.

---

## Raw Tables

### `events`
**Source**: RetailRocket event stream dataset  
**Purpose**: Timestamped user interaction events

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `timestamp` | BIGINT | Unix milliseconds since epoch | 1433221332117 |
| `visitorid` | INT | Unique visitor identifier | 257597 |
| `event` | VARCHAR(50) | Event type: view, addtocart, transaction | view |
| `itemid` | INT | Product ID (nullable for some events) | 424363 |
| `transactionid` | INT | Transaction ID (only for purchases) | 12345 |

**Key Notes**:
- `itemid` can be NULL (e.g., homepage visits)
- `transactionid` only populated for `event = 'transaction'`
- Event sequence: view → addtocart → transaction

---

### `item_properties_part1` / `item_properties_part2`
**Source**: Product metadata (split into 2 files due to size)  
**Purpose**: Product attributes (category, brand, price, etc.)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `timestamp` | BIGINT | When property was recorded | 1433221332117 |
| `itemid` | INT | Product ID | 424363 |
| `property` | VARCHAR(255) | Property name | categoryid, available |
| `value` | TEXT | Property value (can be very long) | 497 |

**Known Properties**:
- `categoryid`: Category identifier
- `available`: Stock availability (0/1)
- Other properties vary by product type

**Data Quality Issues**:
- `value` column contains very long text → causes MySQL errors
- High cardinality, sparse data
- **Solution**: Clean in Python, not SQL

---

### `category_tree`
**Source**: Hierarchical category structure  
**Purpose**: Map categories to parent categories

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `categoryid` | INT | Child category ID | 519 |
| `parentid` | INT | Parent category ID (nullable for root) | 497 |

**Hierarchy**:
- Root categories: `parentid IS NULL`
- Multi-level tree structure
- Used for category-level aggregations

---

## Cleaned Tables

### `events_clean`
**Derived from**: `events`  
**Transformations**:
- Converted `timestamp` to `event_datetime` (DATETIME)
- Removed invalid timestamps
- Removed events with NULL `visitorid`

| Column | Type | Description |
|--------|------|-------------|
| `event_datetime` | DATETIME | Human-readable timestamp |
| `visitorid` | INT | Visitor ID (NOT NULL) |
| `event_type` | VARCHAR(50) | Normalized event type |
| `itemid` | INT | Product ID (nullable) |
| `transactionid` | INT | Transaction ID (nullable) |

---

### `events_sessionized`
**Derived from**: `events_clean`  
**Purpose**: Assign session IDs using 30-minute inactivity threshold

| Column | Type | Description |
|--------|------|-------------|
| `session_id` | VARCHAR(50) | `visitorid_sessionnum` format |
| `visitorid` | INT | Visitor ID |
| `event_datetime` | DATETIME | Event timestamp |
| `event_type` | VARCHAR(50) | Event type |
| `itemid` | INT | Product ID |

**Session Logic**:
- New session starts if gap between events > 30 minutes
- Session ID format: `{visitorid}_{session_number}`
- Example: `257597_1`, `257597_2`

---

## Modeled Tables

### `sessions`
**Derived from**: `events_sessionized`  
**Purpose**: Session-level aggregations

| Column | Type | Description |
|--------|------|-------------|
| `session_id` | VARCHAR(50) | Unique session identifier |
| `visitorid` | INT | Visitor ID |
| `session_start` | DATETIME | First event in session |
| `session_end` | DATETIME | Last event in session |
| `session_duration_seconds` | INT | Duration in seconds |
| `total_events` | INT | Number of events in session |
| `views` | INT | Count of view events |
| `addtocarts` | INT | Count of addtocart events |
| `transactions` | INT | Count of transaction events |

**Business Rules**:
- `session_duration_seconds` = `session_end` - `session_start`
- Sessions with only 1 event have duration = 0

---

### `session_funnels`
**Derived from**: `sessions` + `events_sessionized`  
**Purpose**: Funnel stage flags and conversion metrics

| Column | Type | Description |
|--------|------|-------------|
| `session_id` | VARCHAR(50) | Session identifier |
| `visitorid` | INT | Visitor ID |
| `session_start` | DATETIME | Session start time |
| `session_end` | DATETIME | Session end time |
| `session_duration_seconds` | INT | Duration |
| `has_view` | TINYINT | 1 if session had any view event |
| `has_addtocart` | TINYINT | 1 if session had any addtocart |
| `has_transaction` | TINYINT | 1 if session had any purchase |
| `first_view_time` | DATETIME | Timestamp of first view |
| `first_addtocart_time` | DATETIME | Timestamp of first addtocart |
| `first_transaction_time` | DATETIME | Timestamp of first transaction |
| `valid_funnel` | TINYINT | 1 if funnel is logically valid |

**Valid Funnel Rules**:
- If `has_transaction = 1`, must have `has_view = 1` AND `has_addtocart = 1`
- If `has_addtocart = 1`, must have `has_view = 1`
- Invalid funnels are excluded from conversion metrics

**Target Variable for ML**:
- `has_transaction` is the conversion target (0 = no purchase, 1 = purchase)

---

### `category_tree_clean`
**Derived from**: `category_tree`  
**Purpose**: Cleaned category hierarchy

| Column | Type | Description |
|--------|------|-------------|
| `categoryid` | INT | Category ID |
| `parentid` | INT | Parent category ID (nullable) |

**Cleaning Steps**:
- Removed duplicate category-parent pairs
- Validated no circular references

---

## Feature Engineering Outputs (Python)

### `item_features` (DataFrame)
**Source**: `item_properties_part1` + `item_properties_part2`  
**Purpose**: ML-ready product features

| Column | Type | Description |
|--------|------|-------------|
| `itemid` | INT | Product ID |
| `categoryid` | INT | Primary category |
| `is_available` | BOOLEAN | In stock |
| `price_bucket` | CATEGORY | Price range (low/medium/high) |
| `popularity_score` | FLOAT | Frequency of views |

*Schema finalized during feature engineering phase*

---

### `ml_features` (DataFrame)
**Source**: `session_funnels` + `sessions` + `item_features`  
**Purpose**: Final ML training dataset

**Feature Categories**:
1. **Session Behavioral**: duration, event counts, ratios
2. **Funnel Timing**: time between view → addtocart, addtocart → transaction
3. **Temporal**: hour of day, day of week, weekend flag
4. **Item-level**: category, price, popularity
5. **User History**: sessions per user, conversion rate, recency

*Detailed feature list to be documented after feature engineering*

---

## Key Metrics (From SQL EDA)

### Funnel Conversion Rates
- **View → Add-to-cart**: X% (locked after SQL EDA)
- **Add-to-cart → Transaction**: X% (locked after SQL EDA)
- **Overall Session Conversion**: X% (locked after SQL EDA)

**Python validation MUST match these numbers exactly.**

---

## Data Quality Notes

1. **Missing Values**:
   - `itemid` is NULL for ~X% of events (homepage visits)
   - `transactionid` is NULL unless `event_type = 'transaction'`

2. **Known Anomalies**:
   - Sessions with duration > 4 hours (potential bots)
   - Transactions without views (data quality issue)

3. **Data Volume**:
   - Total events: ~2M
   - Unique visitors: ~X (from SQL EDA)
   - Total sessions: ~X (from SQL EDA)

---

## References
- SQL scripts: `/sql/`
- Python feature engineering: `/python/03_feature_engineering.ipynb`
- Business definitions: `/docs/funnel_definition.md`
