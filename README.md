# E-Commerce Funnel Optimisation & Predictive Conversion Modelling

## Project Overview

This repository contains a comprehensive end-to-end analytics and machine learning pipeline designed to optimise e-commerce conversion funnels through predictive modelling. Built on the RetailRocket dataset comprising over 2.7 million events, this project demonstrates enterprise-grade methodologies for conversion prediction, uplift modelling, and business intelligence reporting.

The solution is architected to meet production standards with rigorous data validation, leakage prevention, and deployment-ready evaluation frameworks suitable for high-stakes business decision-making.

---

## Business Value Proposition

### Core Objectives

- **Conversion Rate Optimisation**: Identify high-value customer segments and predict conversion probability at critical funnel stages
- **Resource Allocation**: Enable data-driven targeting of marketing interventions and personalised experiences
- **Revenue Impact**: Quantify potential revenue uplift through predictive targeting and A/B testing frameworks
- **Operational Excellence**: Establish a single source of truth for key performance indicators (KPIs) with full auditability

### Key Deliverables

1. **Production-Ready ML Models**: CatBoost and XGBoost models trained on leak-safe features with time-causal validation
2. **Business Intelligence Dashboard**: Power BI integration for executive reporting and real-time monitoring
3. **Uplift Modelling Framework**: Methodology for measuring treatment effects and optimising intervention strategies
4. **A/B Testing Infrastructure**: Statistical power analysis and ROI simulation capabilities

---

## Technical Architecture

### Data Engineering Layer (SQL)

The foundation of this project is built on MySQL 8.0+, implementing robust data engineering practices:

- **Sessionisation**: Advanced session boundary detection using a 30-minute inactivity threshold
- **Funnel Construction**: Multi-stage funnel analysis (View → Add to Cart → Purchase) with explicit validity flags
- **KPI Lock Mechanism**: Canonical metric definitions ensuring consistency across all downstream analyses
- **Data Quality Assurance**: Comprehensive validation logic with auditable exclusion tracking

### Analytics & Modelling Layer (Python)

The Python pipeline implements industry best practices for machine learning in production:

#### 1. KPI Reconciliation
- Automated validation against SQL-derived metrics
- Quality gates preventing downstream errors
- Full traceability from raw data to model inputs

#### 2. Feature Engineering
- **Time-Causal Design**: All features computed using only information available at decision time (300 seconds post-session start)
- **Leakage Prevention**: Strict whitelist governance ensuring only validated features enter modelling
- **Temporal Ordering**: User history features computed with proper time-shifting to prevent label leakage
- **Output**: Standardised feature set exported to `data/extracts/ml_features.parquet`

#### 3. Conversion Modelling
- **Time-Based Validation**: Train/test splits respecting temporal ordering (no future information leakage)
- **Class Imbalance Handling**: Appropriate weighting strategies for highly imbalanced conversion data
- **Model Persistence**: Production-ready model artifacts saved to `results/models/`
- **Prediction Export**: Test set predictions available in `data/extracts/test_predictions.parquet`

#### 4. Model Evaluation
- **Top-K Metrics**: Precision@K, Recall@K, and Lift@K aligned with real-world deployment scenarios
- **Separation Diagnostics**: Kolmogorov-Smirnov statistics and distribution analysis
- **Business Metrics**: Focus on actionable metrics rather than misleading accuracy scores

#### 5. Uplift Modelling
- **Simulated RCT Framework**: Demonstrates uplift methodology using potential outcomes simulation
- **Policy Optimisation**: Qini curve analysis and treatment effect estimation
- **Targeting Strategies**: Optimal intervention allocation based on predicted uplift

#### 6. A/B Testing & ROI Analysis
- **Statistical Power Analysis**: Sample size calculations for experimental design
- **ROI Simulation**: Conditional revenue impact estimation based on measured lift
- **Randomisation Guidance**: Best practices for user-level experimental assignment

### Business Intelligence Layer (Power BI)

Executive-facing dashboard connecting:
- Funnel performance metrics from SQL outputs
- Top-K targeting results and model monitoring
- Post-deployment KPI tracking and alerting

*Status: Dashboard structure defined; full implementation in progress*

---

## Performance Metrics

Following rigorous leakage prevention and time-based validation, the models achieve:

- **ROC-AUC**: ~0.91
- **Average Precision (AP)**: 0.30–0.40

These metrics reflect realistic, production-ready performance on highly imbalanced e-commerce conversion data without data leakage artefacts.

---

## Dataset Information

**Source**: RetailRocket E-Commerce Event Stream  
**Scale**: 2.7+ million timestamped events  
**Time Period**: Approximately 4.5 months of transaction data

### Data Tables

| Table | Description | Key Characteristics |
|-------|-------------|---------------------|
| `events.csv` | User interaction events (views, add-to-cart, purchases) | Requires sessionisation and temporal ordering |
| `item_properties*.csv` | Product attribute data | High cardinality, sparse features |
| `category_tree.csv` | Product category hierarchy | Recursive relationships requiring specialised handling |

---

## Project Structure

```
funnel_optimization_project/
├── data/
│   ├── raw/                          # Source CSV files (not version controlled)
│   └── extracts/
│       ├── ml_features.parquet       # Feature engineering output
│       ├── test_predictions.parquet  # Model predictions
│       └── session_funnels.parquet   # Funnel analysis data
│
├── sql/
│   ├── 00_create_tables.sql          # Database schema definition
│   ├── 01_load_raw_data.sql          # Data ingestion
│   ├── 02_clean_events.sql           # Data cleaning and validation
│   ├── 03_sessionization.sql         # Session boundary detection
│   ├── 04_build_funnels.sql          # Funnel construction
│   ├── 05_sql_eda.sql                # Exploratory data analysis
│   └── 06_clean_category_tree.sql    # Category hierarchy processing
│
├── python/
│   ├── utils.py                      # Shared utility functions
│   ├── 01_sql_to_python.ipynb        # Data extraction and validation
│   ├── 02_item_properties_cleaning.ipynb  # Feature preparation
│   ├── 03_feature_engineering.ipynb  # ML feature creation
│   ├── 04_conversion_modeling.ipynb  # Model training
│   ├── 05_model_evaluation.ipynb     # Performance assessment
│   ├── 06_uplift_modeling.ipynb      # Uplift analysis
│   ├── 07_ab_test_simulation.ipynb   # Experimentation framework
│   └── 08_business_insights.ipynb    # Business intelligence
│
├── results/
│   ├── figures/                      # Visualisations and charts
│   ├── models/                       # Trained model artifacts
│   │   ├── catboost_model.cbm        # Primary production model
│   │   └── xgboost_model.json         # Alternative model
│   ├── metrics/                      # Performance metrics exports
│   └── predictions/                  # Prediction outputs
│
├── powerbi/
│   └── Funnel_Optimization_Report .pbix  # Business intelligence dashboard
│
├── docs/                             # Technical documentation
│   ├── data_dictionary.md
│   ├── eda_workflow.md
│   ├── funnel_definition.md
│   ├── ml_integration_strategy.md
│   └── project_structure.md
│
├── requirements.txt                  # Python dependencies
└── README.md                         # This file
```

---

## Getting Started

### Prerequisites

- **Database**: MySQL 8.0 or higher
- **Python**: 3.8 or higher
- **Power BI Desktop**: For dashboard visualisation (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd funnel_optimization_project
   ```

2. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure database connection**
   - Create a `.env` file based on `.env.example`
   - Set your MySQL connection parameters

4. **Load raw data**
   - Place source CSV files in `data/raw/`
   - Execute SQL scripts in `sql/` in numerical order

5. **Run analysis pipeline**
   - Execute Jupyter notebooks in `python/` sequentially
   - Each notebook builds upon previous outputs

---

## Methodology Highlights

### Data Leakage Prevention

This project implements strict controls to prevent common data leakage pitfalls:

- **Temporal Causality**: Features computed only from events occurring before a fixed decision point
- **Label Isolation**: User history features exclude the current session's outcome
- **Feature Whitelisting**: Only explicitly validated features enter the modelling pipeline
- **Time-Based Splits**: Train/test separation respects temporal ordering

### Validation Framework

- **SQL-Python Reconciliation**: Automated checks ensuring metric consistency
- **Cross-Validation**: Time-series aware validation preventing overfitting
- **Business Metrics**: Evaluation focused on deployment-relevant KPIs

---

## Results & Insights

Detailed analysis results, visualisations, and model performance metrics are available in:

- `results/figures/` - Comprehensive visualisations including:
  - Funnel analysis charts
  - Model performance curves (ROC, PR, Qini)
  - Feature importance analysis
  - SHAP value visualisations
  - A/B test simulation results

- `results/metrics/` - Quantitative performance metrics in structured formats

---

## Documentation

Comprehensive technical documentation is available in the `docs/` directory:

- **Data Dictionary**: Complete schema and field definitions
- **EDA Workflow**: Exploratory data analysis methodology
- **Funnel Definition**: Business logic for funnel stage classification
- **ML Integration Strategy**: Model deployment and monitoring approach
- **Project Structure**: Detailed architecture documentation

---

## Contributing

This project follows industry best practices for data science and machine learning. When contributing:

1. Maintain strict adherence to leakage prevention protocols
2. Ensure all SQL and Python metrics reconcile
3. Document any new features or methodologies
4. Update relevant documentation files