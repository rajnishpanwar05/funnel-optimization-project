# Results Directory

This directory stores all model artifacts, metrics, visualizations, and predictions generated during the ML pipeline.

## Structure

### `models/`
Trained model artifacts
- Format: `{model_type}_model.{ext}`
- Example: `catboost_model.cbm`, `xgboost_model.json`
- Includes: model object, hyperparameters, feature names

### `metrics/`
Model performance metrics in JSON format
- Training metrics (AUC, precision, recall, F1)
- Validation metrics
- Confusion matrices
- Example: `model_metrics.json`

### `figures/`
All visualizations and plots
- SHAP summary plots
- Feature importance charts
- ROC curves
- Calibration plots
- Funnel visualizations
- Example: `shap_summary.png`

### `predictions/`
Model predictions on test/production data
- Format: CSV with session_id, predicted_prob, uplift_score
- Example: `predictions_test_set.csv`
- Used for business recommendations and dashboards

## Naming Conventions

Model files use descriptive names without timestamps for simplicity.

Example workflow:
1. Train model → `models/catboost_model.cbm`
2. Evaluate → `metrics/model_metrics.json`
3. Interpret → `figures/shap_summary.png`
4. Predict → `predictions/test_predictions.csv`

## Reproducibility

Each model file includes:
- Random seed
- Feature list (order matters)
- Hyperparameters
- Training data timeframe

This ensures experiments are fully reproducible.
