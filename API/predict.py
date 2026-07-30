"""Quick script that loads the saved model and predicts yield for one new record.

Usage:
    uv run python API/predict.py

Needs best_model.joblib, scaler.joblib, and feature_columns.joblib to already
exist in the summative folder made by code.ipynb.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import model_utils as mu

if __name__ == "__main__":
    new_farm_record = {
        "Region": "North",
        "Soil_Type": "Loam",
        "Crop": "Wheat",
        "Rainfall_mm": 850.0,
        "Temperature_Celsius": 24.5,
        "Fertilizer_Used": True,
        "Irrigation_Used": True,
        "Weather_Condition": "Sunny",
    }

    prediction = mu.predict_one(new_farm_record)
    print("Input record:", new_farm_record)
    print(f"Predicted Yield_tons_per_hectare: {prediction:.4f}")
