"""Shared model I/O and preprocessing used by predict.py and the FastAPI app (main.py).

Kept in one place so the raw-row encoding logic (bool -> int, one-hot, column
reindex) can't drift between the CLI script and the API — both call the same
functions instead of each re-implementing the training-time preprocessing.
"""

import joblib
import pandas as pd

MODEL_PATH = "best_model.joblib"
SCALER_PATH = "scaler.joblib"
FEATURE_COLUMNS_PATH = "feature_columns.joblib"

CATEGORICAL_COLUMNS = ["Region", "Soil_Type", "Crop", "Weather_Condition"]
BOOLEAN_COLUMNS = ["Fertilizer_Used", "Irrigation_Used"]


def load_artifacts():
    """Load (model, scaler, feature_columns) produced by code.ipynb."""
    model = joblib.load(MODEL_PATH)
    scaler = joblib.load(SCALER_PATH)
    feature_columns = joblib.load(FEATURE_COLUMNS_PATH)
    return model, scaler, feature_columns


def save_artifacts(model, scaler, feature_columns) -> None:
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    joblib.dump(list(feature_columns), FEATURE_COLUMNS_PATH)


def encode_raw(df: pd.DataFrame, feature_columns) -> pd.DataFrame:
    """Reproduce training-time encoding for raw (unencoded) rows.

    Any dummy column not present in `df` (e.g. a category not hit by this
    particular batch) is filled with 0, matching training-time encoding.
    """
    df = df.copy()
    for col in BOOLEAN_COLUMNS:
        df[col] = df[col].astype(int)
    df = pd.get_dummies(df, columns=CATEGORICAL_COLUMNS)
    return df.reindex(columns=feature_columns, fill_value=0)


def predict_one(sample: dict) -> float:
    """Predict Yield_tons_per_hectare for one new, raw (unencoded) record."""
    model, scaler, feature_columns = load_artifacts()
    row = encode_raw(pd.DataFrame([sample]), feature_columns)
    row_scaled = scaler.transform(row)
    return float(model.predict(row_scaled)[0])
