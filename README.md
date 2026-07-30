# Crop Yield Prediction

## Mission

My mission is to make Nigerian smallholder farming a data-driven practice — translating soil, weather, and yield data into decisions farmers can act on directly. This project predicts `Yield_tons_per_hectare` from field, weather, and farming-practice data, served through a FastAPI backend and a Flutter mobile app.

## Demo

YouTube video demo: https://youtu.be/SSAMcy-Hwng

## Dataset

`crop_yield.csv` — [Agriculture Crop Yield](https://www.kaggle.com/datasets/samuelotiattakorah/agriculture-crop-yield) dataset on Kaggle: 1,000,000 per-field agricultural records with region, soil type, crop, weather conditions, and farming practices, against a continuous target, `Yield_tons_per_hectare`.

## Project structure

- `code.ipynb` — data exploration, feature engineering, and model comparison/selection
- `main.py` — FastAPI app exposing `/predict` and `/retrain`
- `model_utils.py` — model loading/encoding shared by `main.py` and `API/predict.py`
- `API/predict.py` — standalone script for a one-off prediction
- `crop_yield_app/` — Flutter frontend
- `best_model.joblib`, `scaler.joblib`, `feature_columns.joblib` — saved model artifacts produced by `code.ipynb`

## Model

`code.ipynb` compares four regression algorithms: `SGDRegressor` (gradient descent), `LinearRegression` (OLS), `DecisionTreeRegressor`, and `RandomForestRegressor`. `LinearRegression` (OLS) wins on test MSE/R² and is the one that gets saved and served by the API.

## Running the API locally

```bash
uv sync
uv run uvicorn main:app --reload
```

Then open http://127.0.0.1:8000/docs for the Swagger UI.

### Endpoints

- `POST /predict` — takes the 8 raw input variables (Region, Soil_Type, Crop, Rainfall_mm, Temperature_Celsius, Fertilizer_Used, Irrigation_Used, Weather_Condition) and returns the predicted yield.
- `POST /retrain` — upload a CSV with the same columns as `crop_yield.csv`. The new rows get combined with the original training sample, re-encoded/re-scaled from scratch, and used to refit the current best model. This overwrites the 3 saved artifacts, so `/predict` immediately serves the retrained model.

### CORS

`allow_origins` is an explicit list, never `"*"`, since `/retrain` overwrites the saved model file and an open origin would let any random site trigger that. No cookies or sessions are used anywhere, so `allow_credentials` stays `False`. `allow_methods`/`allow_headers` are limited to what the two endpoints actually need (`GET`/`POST`, `Content-Type`).

## Deploying

Live API: **https://crop-yield-api-9mdx.onrender.com** (Swagger UI at https://crop-yield-api-9mdx.onrender.com/docs).



## Flutter app

This is a mobile app — run it on an Android emulator, iOS simulator, or a physical device (not the web/Chrome target).

```bash
cd crop_yield_app
flutter pub get
flutter devices          # lists available emulators/devices
flutter run -d <device-id>
```

`apiBaseUrl` in `lib/main.dart` defaults to `http://127.0.0.1:8000`, which works for a Windows/macOS/Linux desktop run or a physical device on the same network as the API (using its LAN IP). On an **Android emulator**, `127.0.0.1` refers to the emulator itself, not your computer — change `apiBaseUrl` to `http://10.0.2.2:8000` for local testing there, or point it at the deployed Render URL to skip local networking entirely.

The form has one input widget per prediction variable (8 total): free-text fields for the two continuous numeric inputs (`Rainfall_mm`, `Temperature_Celsius`), and dropdowns for the six fixed-choice inputs (`Region`, `Soil_Type`, `Crop`, `Fertilizer_Used`, `Irrigation_Used`, `Weather_Condition`). Dropdowns are used there instead of free text because those fields are closed enums on the API side (`main.py`'s `Region`/`SoilType`/`Crop`/`WeatherCondition` classes) — a typo like `"north"` instead of `"North"` would fail the API's case-sensitive validation, so constraining input to valid options client-side avoids that entirely.

```bash
flutter run -d chrome --web-port=3000   # quick web preview only — not the mobile build
```
