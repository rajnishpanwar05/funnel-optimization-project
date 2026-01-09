# EDA Workflow: Where and When

## Overview
EDA (Exploratory Data Analysis) happens in **4 distinct stages** throughout this project, each with a specific purpose.

---

## Stage 1: SQL EDA ✅ (Already Complete)

**File**: `sql/05_sql_eda.sql`  
**When**: After sessionization, before Python  
**Purpose**: Lock canonical KPIs as ground truth

### What's Analyzed:
- Dataset overview (row counts, date ranges)
- Funnel counts (sessions with view/cart/purchase)
- Conversion rates (View→Cart, Cart→Transaction, Overall)
- Drop-off analysis (where users abandon)
- Session behavior vs conversion (duration, events)
- Time-to-convert analysis
- Data quality checks (transactions without views, outliers)

### Why This Matters:
These numbers are **truth**. Python must match them exactly.

Example output:
```
Total sessions: 420,000
Overall conversion: 2.3%
View → Cart: 8.7%
Cart → Transaction: 26.4%
```

---

## Stage 2: Python Validation EDA ✅ (Notebook 01)

**File**: `python/01_sql_to_python_enhanced.ipynb`  
**When**: First Python notebook  
**Purpose**: Prove Python data matches SQL

### What's Analyzed:
- Row count validation
- Conversion rate validation
- Basic distributions (session duration, events per session)
- Data quality checks
- Time coverage

### Critical Checkpoint:
```python
assert python_conversion_rate == sql_conversion_rate
# If mismatch → STOP, investigate data loading
```

---

## Stage 3: Item Properties EDA ✅ (Notebook 02)

**File**: `python/02_item_properties_cleaning_enhanced.ipynb`  
**When**: After loading item CSVs  
**Purpose**: Understand product data quality

### What's Analyzed:
- Property distribution (which properties exist?)
- Category coverage (% of items with categoryid)
- Missing value patterns
- Top categories by item count
- Data sparsity assessment

### Output:
- Cleaned `item_features.parquet`
- Quality metrics for product metadata

---

## Stage 4: ML-Focused EDA ⏭️ (Notebook 03 - To Be Created)

**File**: `python/03_feature_engineering.ipynb`  
**When**: After merging sessions + item_features  
**Purpose**: Deep dive for ML feature selection

### 👉 THIS IS WHERE COMPREHENSIVE EDA HAPPENS

#### Univariate Analysis
**Explore each feature individually**:
```python
# Continuous variables
df['session_duration_seconds'].hist(bins=50)
df['event_density'].describe()

# Categorical variables
df['categoryid'].value_counts().plot(kind='bar')
df['hour_of_day'].value_counts().sort_index().plot()
```

**Questions**:
- What's the distribution? (normal, skewed, bimodal?)
- Are there outliers?
- What's the range?
- Missing values?

---

#### Bivariate Analysis
**Relationship between features and target**:
```python
# Conversion rate by feature
df.groupby('hour_of_day')['has_transaction'].mean().plot()
df.groupby('categoryid')['has_transaction'].mean().plot(kind='barh')

# Box plots (continuous vs binary target)
sns.boxplot(x='has_transaction', y='session_duration_seconds', data=df)

# Scatter plots (continuous vs continuous)
plt.scatter(df['session_duration_seconds'], df['view_to_cart_seconds'], 
            c=df['has_transaction'], alpha=0.3)
```

**Questions**:
- Which features correlate with conversion?
- Are relationships linear or non-linear?
- Any interaction effects?

---

#### Multivariate Analysis
**Relationships between features**:
```python
# Correlation matrix
corr_matrix = df[numeric_features].corr()
sns.heatmap(corr_matrix, annot=True, cmap='coolwarm')

# Pairplot (for small feature subsets)
sns.pairplot(df[['session_duration_seconds', 'event_density', 'has_transaction']], 
             hue='has_transaction')
```

**Questions**:
- Are features correlated with each other? (multicollinearity)
- Can we drop redundant features?
- Should we create interaction terms?

---

#### Segmentation Analysis
**Conversion patterns by groups**:
```python
# Conversion by category
category_conversion = df.groupby('categoryid').agg({
    'has_transaction': ['count', 'mean']
}).sort_values(('has_transaction', 'mean'), ascending=False)

# Conversion by time
temporal_conversion = df.groupby(['day_of_week', 'hour_of_day'])['has_transaction'].mean()

# Conversion by user type
user_type_conversion = df.groupby(['sessions_per_user_bucket'])['has_transaction'].mean()
```

**Questions**:
- Do conversion rates vary by segment?
- Which segments are high-value?
- Should we model segments separately?

---

#### Outlier Detection
```python
# Statistical outliers (IQR method)
Q1 = df['session_duration_seconds'].quantile(0.25)
Q3 = df['session_duration_seconds'].quantile(0.75)
IQR = Q3 - Q1
outliers = df[(df['session_duration_seconds'] < Q1 - 1.5*IQR) | 
              (df['session_duration_seconds'] > Q3 + 1.5*IQR)]

# Domain-specific outliers
very_long_sessions = df[df['session_duration_seconds'] > 4*60*60]  # >4 hours
print(f"Sessions >4 hours: {len(very_long_sessions)} ({len(very_long_sessions)/len(df)*100:.1f}%)")
```

**Questions**:
- Are outliers data errors or real behavior?
- Should we cap/remove outliers?
- Do outliers affect model performance?

---

#### Feature Importance Preview
**Before modeling, get rough importance estimates**:
```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.inspection import permutation_importance

# Quick RF model
rf = RandomForestClassifier(n_estimators=100, random_state=42)
rf.fit(X_train, y_train)

# Feature importance
importances = pd.DataFrame({
    'feature': X_train.columns,
    'importance': rf.feature_importances_
}).sort_values('importance', ascending=False)

print(importances.head(20))
```

**Questions**:
- Which features are most predictive?
- Can we drop low-importance features?
- Are there surprising insights?

---

### Deliverables from Notebook 03
1. **Clean feature matrix**: `ml_features.parquet`
2. **EDA report**: Summary of key findings
3. **Feature list**: Final features for modeling
4. **Insights doc**: Business-relevant patterns discovered

---

## Stage 5: Post-Modeling EDA (Notebooks 04-06)

### After training models, analyze:
- **Prediction distributions**: Are probabilities calibrated?
- **Error analysis**: Which sessions are mis-classified?
- **SHAP analysis**: Global + local feature importance
- **Uplift distribution**: Who has highest uplift scores?
- **Segment performance**: Does model work equally well for all groups?

---

## Summary: EDA Timeline

```
SQL EDA (05_sql_eda.sql)
    ↓
Lock KPIs (conversion rates, drop-offs)
    ↓
Python Validation (Notebook 01)
    ↓
Verify numbers match SQL
    ↓
Item Properties EDA (Notebook 02)
    ↓
Understand product data
    ↓
ML-Focused EDA (Notebook 03) ⭐ DEEP DIVE HERE
    ↓
Feature relationships, distributions, segments
    ↓
Modeling (Notebooks 04-05)
    ↓
Post-Modeling EDA (error analysis, SHAP)
    ↓
Business Recommendations
```

---

## Key Principle

**EDA is not a one-time step.** It's iterative:
1. SQL EDA → Understand data quality
2. Validation EDA → Trust your data
3. Feature EDA → Build good features
4. Model EDA → Understand predictions
5. Business EDA → Drive decisions

---

## Tools by Stage

| Stage | Tools | Output |
|-------|-------|--------|
| SQL EDA | MySQL, SELECT queries | KPI numbers |
| Python Validation | Pandas, basic plots | Validation report |
| Item Properties | Pandas, pivot operations | Clean features |
| **ML-Focused EDA** | **Pandas, Seaborn, Matplotlib** | **Feature insights** |
| Post-Modeling | SHAP, calibration plots | Model insights |

---

**Bottom Line**: Stage 4 (Notebook 03) is where you spend the most EDA time. That's where you discover patterns that drive model performance and business insights.
