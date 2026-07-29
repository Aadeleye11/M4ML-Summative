"""Model loading and preprocessing shared by predict.py and main.py.

Put it all in one place so the encoding logic (bool to int, one-hot, reindex
columns) doesn't end up different in the CLI script vs the API. Both just
call these same functions instead of copy-pasting the preprocessing.
"""

import joblib
import pandas as pd

MODEL_PATH = "best_model.joblib"
SCALER_PATH = "scaler.joblib"
FEATURE_COLUMNS_PATH = "feature_columns.joblib"

CATEGORICAL_COLUMNS = ["Region", "Soil_Type", "Crop", "Weather_Condition"]
BOOLEAN_COLUMNS = ["Fertilizer_Used", "Irrigation_Used"]


def load_artifacts():
    """Loads the model, scaler, and feature columns saved by code.ipynb."""
    model = joblib.load(MODEL_PATH)
    scaler = joblib.load(SCALER_PATH)
    feature_columns = joblib.load(FEATURE_COLUMNS_PATH)
    return model, scaler, feature_columns


def save_artifacts(model, scaler, feature_columns) -> None:
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    joblib.dump(list(feature_columns), FEATURE_COLUMNS_PATH)


def encode_raw(df: pd.DataFrame, feature_columns) -> pd.DataFrame:
    """Encodes a raw row the same way it was done during training.

    If a dummy column is missing from `df` (like a category that just didn't
    show up in this batch), it gets filled with 0 to match what training saw.
    """
    df = df.copy()
    for col in BOOLEAN_COLUMNS:
        df[col] = df[col].astype(int)
    df = pd.get_dummies(df, columns=CATEGORICAL_COLUMNS)
    return df.reindex(columns=feature_columns, fill_value=0)


def predict_one(sample: dict) -> float:
    """Predicts Yield_tons_per_hectare for one raw, unencoded record."""
    model, scaler, feature_columns = load_artifacts()
    row = encode_raw(pd.DataFrame([sample]), feature_columns)
    row_scaled = scaler.transform(row)
    return float(model.predict(row_scaled)[0])
