# Funnel Definition

## Business Context

E-commerce conversion funnels represent the customer journey from initial product discovery to final purchase. Understanding where users drop off is critical for optimizing revenue and user experience.

---

## Funnel Stages

### Stage 1: View
**Definition**: User views a product page  
**Event Type**: `event_type = 'view'`  
**Business Meaning**: Product discovery, browsing intent  
**Behavioral Indicators**:
- Category exploration
- Search result clicks
- Recommendation clicks

### Stage 2: Add-to-Cart
**Definition**: User adds product to shopping cart  
**Event Type**: `event_type = 'addtocart'`  
**Business Meaning**: Purchase intent, consideration phase  
**Behavioral Indicators**:
- Active engagement
- Price sensitivity evaluation
- Comparison shopping

### Stage 3: Transaction
**Definition**: User completes purchase  
**Event Type**: `event_type = 'transaction'`  
**Business Meaning**: Conversion, revenue generation  
**Success Metric**: Session-level conversion rate

---

## Funnel Logic

### Valid Funnel Rules
A session has a **valid funnel** if it follows these constraints:

1. **No Skip Rules**:
   - If `has_transaction = 1`, then `has_view = 1` AND `has_addtocart = 1`
   - If `has_addtocart = 1`, then `has_view = 1`

2. **Temporal Ordering**:
   - `first_view_time` ≤ `first_addtocart_time` ≤ `first_transaction_time`

3. **Invalid Patterns** (Excluded from analysis):
   - Transaction without view
   - Transaction without add-to-cart
   - Add-to-cart without view

### Why Enforce Valid Funnels?
Invalid funnels indicate:
- Data quality issues (missing events)
- Bot traffic
- Measurement errors

**Analysis Impact**: Only `valid_funnel = 1` sessions are used for conversion metrics.

---

## Session Definition

### Sessionization Rules
**Inactivity Threshold**: 30 minutes  
**Logic**: New session starts if time gap between consecutive events > 1800 seconds (30 minutes)

**Business Rationale**:
- Industry standard for e-commerce analytics
- Balances granularity vs session continuity
- Aligns with typical shopping session duration

**Implementation**:
- SQL window functions with `LAG()` to compute inter-event gaps
- Session ID format: `{visitorid}_{session_number}`
- Example: User 12345's 3rd session → `12345_3`

### Session Boundaries
- **Session Start**: Timestamp of first event in session
- **Session End**: Timestamp of last event in session
- **Session Duration**: `session_end - session_start` (in seconds)

**Edge Cases**:
- Single-event sessions have duration = 0
- Sessions crossing midnight are not split (continuity preserved)

---

## Conversion Metrics

### Primary KPI: Session-Level Conversion Rate
```
Overall Conversion Rate = (Sessions with Transaction) / (Total Valid Sessions)
```

### Stage-Specific Metrics
```
View → Add-to-Cart Rate = (Sessions with Add-to-Cart) / (Sessions with View)
Add-to-Cart → Transaction Rate = (Sessions with Transaction) / (Sessions with Add-to-Cart)
```

### Drop-Off Analysis
**Drop-Off Categories**:
1. **Dropped after view**: `has_view = 1` AND `has_addtocart = 0`
2. **Dropped after add-to-cart**: `has_addtocart = 1` AND `has_transaction = 0`
3. **Converted**: `has_transaction = 1`
4. **No meaningful activity**: None of the above

**Business Insight**: Largest drop-off stage = highest optimization opportunity

---

## Time-to-Convert

### Definition
Time elapsed between first view and first transaction within a session.

### Calculation
```sql
TIMESTAMPDIFF(SECOND, first_view_time, first_transaction_time)
```

### Business Interpretation
- **Fast conversions** (<5 min): High purchase intent, targeted search
- **Medium conversions** (5-30 min): Comparison shopping, consideration
- **Slow conversions** (>30 min but same session): Extended deliberation

**Use Case**: Identify urgency patterns, optimize intervention timing

---

## Data Integrity Checks

### Sanity Checks (Always Validate)
1. **Transactions without views**: Should be ~0%
2. **Add-to-cart without views**: Should be ~0%
3. **Sessions with multiple transactions**: Should be minimal
4. **Extremely long sessions** (>4 hours): Potential bots/anomalies

### SQL Validation Queries
See: `/sql/05_sql_eda.sql` (Section 7: Guardrails)

---

## Machine Learning Target Variable

### Target Definition
**Column**: `has_transaction` from `session_funnels` table  
**Type**: Binary classification (0 = no conversion, 1 = conversion)  
**Granularity**: Session-level

### Why Session-Level?
- Business decisions are made at session granularity
- Captures full user journey, not individual events
- Aligns with intervention strategies (e.g., cart abandonment emails)

### Class Imbalance
**Expected Conversion Rate**: 2-5% (typical e-commerce range)  
**Implications**:
- Imbalanced classes → use stratified sampling
- Evaluation metrics: Precision-Recall, AUC-ROC (not accuracy)
- Consider SMOTE or class weighting

---

## Assumptions and Limitations

### Assumptions
1. **30-minute threshold is appropriate** for this dataset
   - Validated against business context
   - Industry standard
2. **Event order in raw data is preserved**
   - Timestamps are accurate
   - No clock drift issues
3. **One transaction per session is typical**
   - Multi-transaction sessions are rare (<1%)

### Known Limitations
1. **Cross-device tracking**: Not available
   - Same user on mobile + desktop = 2 different visitors
2. **Offline conversions**: Not captured
   - Browse online, buy in-store
3. **Return visits**: Treated as new sessions
   - No long-term user journey tracking beyond sessions

### Impact on Analysis
- Conversion rates are **lower bound** estimates (due to cross-device)
- Models predict **session-level** conversion, not user-level lifetime value

---

## Business Use Cases

### 1. Drop-Off Identification
**Question**: Where do we lose the most users?  
**Answer**: Stage with highest drop-off rate  
**Action**: Prioritize UX improvements at that stage

### 2. Predictive Intervention
**Question**: Which sessions are at risk of abandoning?  
**Answer**: ML model predicts low conversion probability  
**Action**: Trigger real-time interventions (discounts, recommendations)

### 3. Segment Analysis
**Question**: Do conversion patterns differ by category/time/user?  
**Answer**: Stratified funnel analysis  
**Action**: Personalized experiences

### 4. A/B Test Prioritization
**Question**: Which interventions have highest expected lift?  
**Answer**: Uplift modeling + simulation  
**Action**: Allocate engineering resources efficiently

---

## References
- SQL Implementation: `/sql/04_build_funnels.sql`
- Python Validation: `/python/01_sql_to_python_enhanced.ipynb`
- Data Dictionary: `/docs/data_dictionary.md`
- ML Integration Strategy: `/docs/ml_integration_strategy.md`
