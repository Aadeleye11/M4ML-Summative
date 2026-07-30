"""FastAPI wrapper around the crop yield model trained in code.ipynb.

Run locally:
    uv run uvicorn main:app --reload

Deploy on Render:
    Build Command: pip install -r requirements.txt
    Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
"""

from io import StringIO

import pandas as pd
from enum import Enum
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.base import clone
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

import model_utils as mu

app = FastAPI(
    title="Crop Yield Prediction API",
    description=(
        "Predicts Yield_tons_per_hectare from field, weather, and farming-practice "
        "data using the best regression model selected in code.ipynb."
    ),
    version="1.0.0",
)

# CORS setup
# only allowing specific origins here (not "*") because /retrain can overwrite
# the saved model file, so random websites shouldn't be able to hit that route.
# no cookies or auth tokens used anywhere so allow_credentials just stays False.
# the two routes below only ever need GET/POST and a Content-Type header.
ALLOWED_ORIGINS = [
    "http://localhost:3000",  # react/next dev server
    "http://localhost:5173",  # vite dev server
    "https://your-frontend-domain.com",  # TODO: put the real deployed url here
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


# request/response schema
# categories and min/max values below came straight from crop_yield.csv
# (just ran df[col].unique() and .min()/.max()), so pydantic rejects bad
# input before it ever gets near the model.
class Region(str, Enum):
    north = "North"
    south = "South"
    east = "East"
    west = "West"


class SoilType(str, Enum):
    clay = "Clay"
    loam = "Loam"
    sandy = "Sandy"
    silt = "Silt"
    peaty = "Peaty"
    chalky = "Chalky"


class Crop(str, Enum):
    wheat = "Wheat"
    rice = "Rice"
    maize = "Maize"
    barley = "Barley"
    soybean = "Soybean"
    cotton = "Cotton"


class WeatherCondition(str, Enum):
    sunny = "Sunny"
    rainy = "Rainy"
    cloudy = "Cloudy"


class PredictionRequest(BaseModel):
    Region: Region
    Soil_Type: SoilType
    Crop: Crop
    Rainfall_mm: float = Field(..., ge=100.0, le=1000.0, description="Seasonal rainfall in mm")
    Temperature_Celsius: float = Field(..., ge=15.0, le=40.0, description="Average temperature in °C")
    Fertilizer_Used: bool
    Irrigation_Used: bool
    Weather_Condition: WeatherCondition


class PredictionResponse(BaseModel):
    predicted_yield_tons_per_hectare: float


class RetrainResponse(BaseModel):
    message: str
    algorithm: str
    metrics: dict


@app.get("/")
def root():
    return {"message": "Crop Yield Prediction API. See /docs for the interactive Swagger UI."}


@app.post("/predict", response_model=PredictionResponse)
def predict(payload: PredictionRequest):
    try:
        yhat = mu.predict_one(payload.model_dump())
    except FileNotFoundError:
        raise HTTPException(status_code=503, detail="Model artifacts not found on server; train the model first.")
    return PredictionResponse(predicted_yield_tons_per_hectare=yhat)


@app.post("/retrain", response_model=RetrainResponse)
async def retrain(file: UploadFile = File(...)):
    """Retrain the model on the original data plus whatever CSV gets uploaded.

    The CSV needs the same columns as crop_yield.csv: Region, Soil_Type, Crop,
    Rainfall_mm, Temperature_Celsius, Fertilizer_Used, Irrigation_Used,
    Weather_Condition, Days_to_Harvest, Yield_tons_per_hectare.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Upload a .csv file")

    raw = await file.read()
    try:
        new_df = pd.read_csv(StringIO(raw.decode("utf-8")))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not parse CSV: {exc}")

    required_cols = {
        "Region", "Soil_Type", "Crop", "Rainfall_mm", "Temperature_Celsius",
        "Fertilizer_Used", "Irrigation_Used", "Weather_Condition",
        "Days_to_Harvest", "Yield_tons_per_hectare",
    }
    missing = required_cols - set(new_df.columns)
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {sorted(missing)}")

    try:
        base_df = pd.read_csv("crop_yield.csv").sample(100_000, random_state=42)
    except FileNotFoundError:
        raise HTTPException(status_code=503, detail="Base training data (crop_yield.csv) not found on server.")

    combined = pd.concat([base_df, new_df[list(required_cols)]], ignore_index=True)
    combined = combined.drop(columns=["Days_to_Harvest"])
    for col in mu.BOOLEAN_COLUMNS:
        combined[col] = combined[col].astype(int)
    combined = pd.get_dummies(combined, columns=mu.CATEGORICAL_COLUMNS, drop_first=True)

    X = combined.drop(columns=["Yield_tons_per_hectare"])
    y = combined["Yield_tons_per_hectare"]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    current_model, _, _ = mu.load_artifacts()
    new_model = clone(current_model)
    new_model.fit(X_train_s, y_train)

    pred = new_model.predict(X_test_s)
    metrics = {"MSE": mean_squared_error(y_test, pred), "R2": r2_score(y_test, pred)}

    mu.save_artifacts(new_model, scaler, X.columns.tolist())

    return RetrainResponse(
        message=f"Retrained on {len(new_df)} new row(s) + {len(base_df)} existing rows.",
        algorithm=type(new_model).__name__,
        metrics=metrics,
    )
