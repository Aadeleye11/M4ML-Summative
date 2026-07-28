"""Standalone script: load the saved best model and predict crop yield for a new record.

Usage:
    uv run python predict.py

Requires best_model.joblib, scaler.joblib and feature_columns.joblib to already
exist in this directory (produced by code.ipynb).
"""

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
