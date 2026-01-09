# Project Structure

## Complete Directory Tree

```
funnel_optimization_project/
│
├── data/
│   ├── raw/                          # ✅ Original CSV files (do not modify)
│   │   ├── events.csv
│   │   ├── item_properties_part1.csv
│   │   ├── item_properties_part2.csv
│   │   └── category_tree.csv
│   │
│   └── extracts/                     # Optional: SQL exports if needed
│       └── (CSV exports from MySQL)
│
├── sql/                              # ✅ Database layer (completed)
│   ├── 00_create_tables.sql          # Schema definitions
│   ├── 01_load_raw_data.sql          # Load CSVs → MySQL
│   ├── 02_clean_events.sql           # Clean events table
│   ├── 03_sessionization.sql         # Build sessions (30-min threshold)
│   ├── 04_build_funnels.sql          # Create session_funnels table
│   ├── 05_sql_eda.sql                # Lock canonical KPIs
│   └── 06_clean_category_tree.sql    # Clean category hierarchy
│
├── python/                           # ✅ ML & feature engineering (completed)
│   ├── utils.py                      # ✅ Database connection & helpers
│   ├── 01_sql_to_python.ipynb          # Load data from MySQL, validate
│   ├── 02_item_properties_cleaning.ipynb  # Clean item properties
│   ├── 03_feature_engineering.ipynb  # Build ML features
│   ├── 04_conversion_modeling.ipynb  # Train LR, CatBoost, XGBoost
│   ├── 05_model_evaluation.ipynb     # Advanced diagnostics
│   ├── 06_uplift_modeling.ipynb      # Causal inference (T-Learner)
│   ├── 07_ab_test_simulation.ipynb   # Experimentation framework
│   └── 08_business_insights.ipynb    # Final strategic recommendations
│
├── results/                          # Model outputs
│   ├── models/                       # Trained model artifacts (.pkl)
│   ├── metrics/                      # Performance metrics (JSON)
│   ├── figures/                      # SHAP plots, ROC curves, etc.
│   └── predictions/                  # Prediction CSVs
│
├── powerbi/                          # 📊 Executive dashboard
│   └── funnel_dashboard.pbix         # Power BI file
│
├── docs/                             # Documentation (professional touch)
│   ├── data_dictionary.md            # All tables & columns defined
│   ├── funnel_definition.md          # Business logic & rules
│   ├── modelling_strategy.md         # ML approach (to be created)
│   ├── business_recommendations.md   # Final recommendations (after ML)
│   └── project_structure.md          # This file
│
├── .env.example                      # Database config template
├── .gitignore                        # Excludes data, .env, models
├── requirements.txt                  # Python dependencies
├── README.md                         # Project overview
└── WARP.md                           # Development guide
```

## Execution Flow

### Phase 1: SQL ( Completed)
```
Raw CSVs → MySQL → Clean Events → Sessionization → Funnels → SQL EDA
```

**Outputs**:
- `sessions` table (session-level aggregations)
- `session_funnels` table (funnel flags + timings)
- Locked KPIs (conversion rates, drop-offs)

---

### Phase 2: Python ML (Completed)
```
MySQL → Python → Item Properties Cleaning → Feature Engineering → ML Models → Predictions
```

**Step-by-step**:

#### Step 1: Data Extraction (`01_sql_to_python.ipynb`)
- Pull `sessions`, `session_funnels`, `events_clean` from MySQL
- Validate row counts match SQL
- Validate conversion rates match SQL EDA exactly

#### Step 2: Item Properties (`02_item_properties_cleaning.ipynb`)
- Load `item_properties_part1` + `part2` from CSV
- Deduplicate by (itemid, property, latest timestamp)
- Extract: categoryid, available, price, brand
- Create `item_features` DataFrame

#### Step 3: Feature Engineering (`03_feature_engineering.ipynb`)
- Merge sessions + funnels + item_features
- Create features:
  - Behavioral: duration, event counts, ratios
  - Temporal: hour, day of week, weekend
  - Timing: view_to_cart_seconds, cart_to_transaction_seconds
  - Item: category, price_bucket, popularity
  - User history: sessions per user, conversion rate
- Output: `ml_features` DataFrame

#### Step 4: Conversion Model (`04_conversion_modeling.ipynb`)
- Target: `has_transaction` (binary)
- Models: Logistic Regression, CatBoost, XGBoost
- Time-based train/test split
- Evaluation: AUC, precision, recall, calibration
- SHAP interpretation
- Save model → `results/models/`

#### Step 5: Model Evaluation (`05_model_evaluation.ipynb`)
- Advanced diagnostics: calibration plots, lift curves
- Threshold optimization for business objectives
- Segment performance analysis
- Error analysis and model stability checks

#### Step 6: Uplift Model (`06_uplift_modeling.ipynb`)
- Simulate treatment effect (e.g., discount offer)
- Train: T-Learner (control + treatment models)
- Calculate uplift: P(convert|treatment) - P(convert|control)
- Identify high-uplift segments
- Save uplift scores → `results/predictions/`

#### Step 7: A/B Test Simulation (`07_ab_test_simulation.ipynb`)
- Use uplift scores to simulate test
- Calculate: expected lift, confidence intervals, sample size
- Power analysis for experimental design
- Bayesian analysis and multi-armed bandits

#### Step 8: Business Insights (`08_business_insights.ipynb`)
- Synthesize all analysis into executive recommendations
- Strategic action items prioritized by impact/effort
- ROI quantification and risk assessment
- Export final recommendations

---

### Phase 3: Power BI (📊 Pending)
```
Predictions → Power BI → Executive Dashboard
```

**Dashboard Pages**:
1. Funnel Overview: Stage-by-stage conversion
2. Drop-Off Analysis: Where users abandon
3. Predictive Scores: High-risk sessions
4. Uplift Recommendations: Who to target
5. ROI Simulation: Expected business impact

---

## Key Files by Purpose

### Must-Read Documentation
1. `README.md` → Project overview
2. `docs/data_dictionary.md` → All tables/columns
3. `docs/funnel_definition.md` → Business logic
4. `WARP.md` → Development guide

### Critical Python Files
1. `python/utils.py` → Database connection
2. `python/01_sql_to_python.ipynb` → Validation checkpoint
3. `python/04_conversion_modeling.ipynb` → Core ML model
4. `python/06_uplift_modeling.ipynb` → Advanced causal ML
5. `python/08_business_insights.ipynb` → Final recommendations

### SQL Truth
1. `sql/05_sql_eda.sql` → Canonical KPIs (Python must match these)
2. `sql/04_build_funnels.sql` → Funnel construction logic

---

## Data Flow Diagram

```
┌─────────────┐
│  Raw CSVs   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    MySQL    │ ← SQL Scripts (01-06)
│  (Cleaned)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Python    │ ← Feature Engineering + ML
│  DataFrames │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Models    │ ← CatBoost, XGBoost, Uplift
│ Predictions │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Power BI   │ ← Executive Dashboard
│  Dashboard  │
└─────────────┘
```

---

## Next Steps (In Order)

1. ✅ Folder structure created
2. ✅ Documentation scaffolding complete
3. ✅ **Created all 8 Jupyter notebooks** (01-08)
4. ✅ Notebooks validated and tested
5. ✅ Complete ML pipeline (LR, CatBoost, XGBoost)
6. ✅ Advanced notebooks (Uplift, A/B Testing)
7. ⏭️ Power BI dashboard
8. ⏭️ Final portfolio presentation

---

## Reproducibility Checklist

- [ ] `.env` file created (from `.env.example`)
- [ ] Virtual environment set up
- [ ] `requirements.txt` installed
- [ ] MySQL database running with completed SQL scripts
- [ ] SQL EDA metrics documented
- [x] Python notebooks run in sequence (01 → 08)
- [ ] All models saved with timestamps
- [ ] SHAP plots generated
- [ ] Power BI connected to predictions

---

## Professional Standards

This project demonstrates:
- ✅ Clear separation of concerns (SQL vs Python)
- ✅ Production-grade folder structure
- ✅ Comprehensive documentation
- ✅ Version control with Git
- ✅ Reproducible research practices
- ✅ Business-focused outputs (not just models)
- ✅ Advanced ML techniques (uplift modeling)
- ✅ Decision science (A/B test simulation)

**Target Roles**: Growth Data Scientist, Product Analyst, ML Engineer, Decision Scientist
