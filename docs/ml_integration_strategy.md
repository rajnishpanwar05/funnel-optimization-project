# ML Integration Strategy

## Question: Where Does ML Fit in This Project?

**Short Answer**: ML starts AFTER SQL data engineering is complete. It uses the sessionized data to predict conversions and optimize interventions.

---

## The Complete Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA ENGINEERING (SQL)                    │
│                          ✅ DONE                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
              events → sessions → session_funnels
                              ↓
                    Target: has_transaction
                    Features: timing, counts, etc.

┌─────────────────────────────────────────────────────────────┐
│              FEATURE ENGINEERING (Python)                    │
│                     🚧 NEXT STEP                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
          Load MySQL tables → Clean item properties
                              ↓
              Create behavioral + temporal features
                              ↓
                    ml_features DataFrame

┌─────────────────────────────────────────────────────────────┐
│                    MACHINE LEARNING                          │
│                      📍 ML STARTS HERE                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
         ┌────────────────────┴────────────────────┐
         │                                         │
    CONVERSION                                 UPLIFT
    PREDICTION                                 MODELING
         │                                         │
    "Will session                         "Who should we
     convert?"                            target?"
         │                                         │
         ▼                                         ▼
    Probability Score                      Uplift Score
    (0.0 - 1.0)                           (treatment effect)

┌─────────────────────────────────────────────────────────────┐
│                    BUSINESS DECISIONS                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
              A/B Test Simulation + ROI Analysis
                              ↓
                    Power BI Dashboard
```

---

## ML Use Cases (Detailed)

### 1. Conversion Prediction (Supervised Learning)

**Business Question**: "Which sessions are likely to abandon without converting?"

**Data Source**: `session_funnels` table from MySQL

**Target Variable**: 
- Column: `has_transaction` (from SQL)
- Type: Binary (0 = no purchase, 1 = purchase)
- Granularity: Session-level

**Features** (examples):
- `session_duration_seconds` (from SQL)
- `has_view`, `has_addtocart` (from SQL)
- Time between view → addtocart (computed in Python)
- Hour of day, day of week (extracted from timestamps)
- Category browsing patterns (from item properties)
- User history metrics (sessions per user, conversion rate)

**Models**:
- Logistic Regression (baseline)
- CatBoost (gradient boosting, handles categorical features natively)
- XGBoost (alternative gradient boosting)

**Evaluation**:
- AUC-ROC (primary metric for imbalanced data)
- Precision-Recall curves
- Calibration (are probabilities accurate?)
- SHAP values (feature importance)

**Output**: 
- Probability score per session (e.g., 0.03 = 3% chance of conversion)
- File: `results/predictions/conversion_predictions.csv`

**Business Use**:
- Identify high-risk abandonment sessions in real-time
- Trigger interventions (discounts, reminders, recommendations)

---

### 2. Uplift Modeling (Causal ML)

**Business Question**: "Who benefits MOST from an intervention (e.g., discount)?"

**Problem with Conversion Prediction**:
- High conversion probability → might convert anyway (no need for discount)
- Low conversion probability → might not convert even with discount
- **We need to find users where treatment CHANGES the outcome**

**Uplift Definition**:
```
Uplift = P(convert | treatment) - P(convert | control)
```

**Approach**: T-Learner (Two-Model Approach)
1. Train model on control group (no intervention)
2. Train model on treatment group (with intervention)
3. Calculate uplift = treatment_prob - control_prob

**Simulation** (since we don't have real A/B test data):
- Randomly assign sessions to control/treatment
- Assume treatment increases conversion by X% for certain segments
- Train models on simulated data
- Validate uplift scores

**Output**:
- Uplift score per session (e.g., +0.08 = 8% lift from treatment)
- File: `results/predictions/uplift_scores.csv`

**Business Use**:
- Target users with highest uplift (maximize ROI)
- Avoid wasting interventions on users who'd convert anyway
- Avoid targeting users who won't convert even with intervention

---

### 3. A/B Test Simulation (Decision Science)

**Business Question**: "How many users should we target? What's the expected lift?"

**Inputs**:
- Uplift scores from Model 2
- Current conversion rate (from SQL EDA)
- Treatment cost (e.g., $5 discount per user)
- Revenue per conversion (e.g., $50 average order value)

**Simulation**:
- Select top X% of users by uplift score
- Estimate expected lift in conversion rate
- Calculate confidence intervals
- Compute ROI = (revenue gain - treatment cost) / treatment cost

**Example Output**:
```
Strategy: Target top 10% by uplift score
Expected lift: 12% increase in conversion
Confidence: 95% CI [8%, 16%]
Cost: $5/user × 10,000 users = $50,000
Revenue: $50/conv × 1,200 extra conversions = $60,000
ROI: ($60k - $50k) / $50k = 20% positive ROI
```

**Business Use**:
- Justify marketing spend
- Optimize intervention budget
- Prioritize which segments to target

---

## Why This ML Approach is Advanced

### Most Candidates Do:
❌ Load Iris dataset  
❌ Train random forest  
❌ "Look, 95% accuracy!"  
❌ No business context

### You're Doing:
✅ Real-world data (2M+ events)  
✅ End-to-end pipeline (SQL → Python → ML)  
✅ Business-relevant target (conversion)  
✅ **Causal inference** (uplift modeling)  
✅ Decision science (A/B test ROI)  
✅ Interpretability (SHAP analysis)  
✅ Production mindset (time-based split, no leakage)

**This is Growth Data Science / Decision Science level work.**

---

## ML Workflow (Step-by-Step)

### Step 1: Validate SQL → Python
**File**: `python/01_sql_to_python_enhanced.ipynb`

```python
# Load data from MySQL
sessions = db.get_table('sessions')
funnels = db.get_table('session_funnels')

# Validate row counts
assert len(sessions) == SQL_EDA_COUNT

# Validate conversion rate
conversion_rate = funnels['has_transaction'].mean()
assert conversion_rate ≈ SQL_EDA_CONVERSION_RATE  # Must match!
```

**Critical**: If numbers don't match SQL, STOP. Fix data issues first.

---

### Step 2: Feature Engineering
**File**: `python/03_feature_engineering.ipynb`

```python
# Merge tables
df = funnels.merge(sessions, on='session_id')

# Temporal features
df['hour'] = df['session_start'].dt.hour
df['is_weekend'] = df['session_start'].dt.dayofweek >= 5

# Timing features
df['view_to_cart_seconds'] = (
    df['first_addtocart_time'] - df['first_view_time']
).dt.total_seconds()

# Ratios
df['addtocart_rate'] = df['has_addtocart'] / df['has_view']

# User history
user_stats = df.groupby('visitorid').agg({
    'session_id': 'count',  # sessions per user
    'has_transaction': 'mean'  # user conversion rate
})
df = df.merge(user_stats, on='visitorid', suffixes=('', '_user'))
```

**Output**: `ml_features` DataFrame with 20-50 features

---

### Step 3: Train Conversion Model
**File**: `python/04_conversion_modeling.ipynb`

```python
# Train/test split (TIME-BASED to prevent leakage)
train = df[df['session_start'] < '2023-05-01']
test = df[df['session_start'] >= '2023-05-01']

# Target and features
X_train = train[feature_cols]
y_train = train['has_transaction']

# Train model
model = CatBoostClassifier(random_state=42, verbose=0)
model.fit(X_train, y_train)

# Evaluate
y_pred_proba = model.predict_proba(X_test)[:, 1]
auc = roc_auc_score(y_test, y_pred_proba)

# SHAP interpretation
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)
shap.summary_plot(shap_values, X_test)
```

**Output**: 
- Model file: `results/models/catboost_model.cbm`
- Metrics: `results/metrics/model_metrics.json`
- SHAP plot: `results/figures/shap_summary.png`

---

### Step 4: Uplift Model
**File**: `python/07_uplift_modeling.ipynb`

```python
# Simulate treatment assignment
df['treatment'] = np.random.binomial(1, 0.5, len(df))

# Simulate treatment effect (for demo purposes)
# In reality, you'd use A/B test data
df.loc[df['treatment'] == 1, 'has_transaction'] *= 1.15  # 15% lift

# Train control model
control_model = CatBoostClassifier(verbose=0)
control_model.fit(X[df['treatment'] == 0], y[df['treatment'] == 0])

# Train treatment model
treatment_model = CatBoostClassifier(verbose=0)
treatment_model.fit(X[df['treatment'] == 1], y[df['treatment'] == 1])

# Calculate uplift
df['p_control'] = control_model.predict_proba(X)[:, 1]
df['p_treatment'] = treatment_model.predict_proba(X)[:, 1]
df['uplift'] = df['p_treatment'] - df['p_control']

# Identify high-uplift segments
high_uplift = df[df['uplift'] > df['uplift'].quantile(0.9)]
```

**Output**: `results/predictions/uplift_scores.csv`

---

### Step 5: A/B Test Simulation
**File**: `python/08_ab_test_simulation.ipynb`

```python
# Target top 10% by uplift
target_sessions = df.nlargest(int(0.1 * len(df)), 'uplift')

# Expected lift
baseline_conversion = df['has_transaction'].mean()
treatment_conversion = target_sessions['has_transaction'].mean()
lift = (treatment_conversion - baseline_conversion) / baseline_conversion

# ROI calculation
cost_per_user = 5
revenue_per_conversion = 50
expected_conversions = len(target_sessions) * treatment_conversion
expected_revenue = expected_conversions * revenue_per_conversion
total_cost = len(target_sessions) * cost_per_user
roi = (expected_revenue - total_cost) / total_cost

print(f"Expected lift: {lift:.1%}")
print(f"ROI: {roi:.1%}")
```

**Output**: Business recommendations document

---

## Integration with Power BI

### Data Sources for Dashboard
1. **Funnel metrics**: From MySQL `session_funnels` table
2. **Predictions**: From `results/predictions/conversion_predictions.csv`
3. **Uplift scores**: From `results/predictions/uplift_scores.csv`
4. **SHAP summaries**: From Python exports

### Dashboard Pages
1. **Funnel Overview**: SQL-derived metrics (baseline)
2. **Risk Segments**: ML predictions (high-risk sessions)
3. **Intervention Strategy**: Uplift scores (who to target)
4. **ROI Projection**: Simulation results (expected impact)

---

## Key Success Criteria

### Data Validation
✅ Python row counts match SQL  
✅ Python conversion rate matches SQL EDA  
✅ No data leakage (time-based split)

### Model Quality
✅ AUC > 0.75 (good discrimination)  
✅ Calibration plot shows accurate probabilities  
✅ SHAP values make business sense

### Business Impact
✅ Identified highest drop-off stage  
✅ Quantified revenue loss from abandonment  
✅ Predicted which sessions to target  
✅ Estimated ROI of intervention strategy

---

## Timeline Estimate

| Phase | Tasks | Duration |
|-------|-------|----------|
| SQL → Python | Notebook 01 (validation) | 1-2 hours |
| Item Properties | Notebook 02 (cleaning) | 2-3 hours |
| Feature Engineering | Notebook 03 | 3-4 hours |
| Conversion Model | Notebook 04 | 2-3 hours |
| Uplift Model | Notebook 05 | 3-4 hours |
| A/B Simulation | Notebook 06 | 2-3 hours |
| Power BI | Dashboard creation | 3-5 hours |
| **Total** | | **16-24 hours** |

**Recommendation**: Work in phases. Complete 01 → 02 → 03 first, then do ML (04-06).

---

## Summary

**ML fits AFTER data engineering:**
1. SQL creates clean, sessionized data with target variable (`has_transaction`)
2. Python loads that data and engineers features
3. ML models predict conversion (baseline) and uplift (advanced)
4. Business simulation translates predictions into ROI
5. Power BI visualizes insights for executives

**This is not "ML for ML's sake" — every model directly answers a business question.**

That's what makes this project exceptional.
