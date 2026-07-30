# Crop Yield Prediction

Predicts `Yield_tons_per_hectare` from field, weather, and farming-practice data using a regression model, served through a FastAPI backend and a Flutter frontend.

## Project structure

- `code.ipynb` — data exploration, feature engineering, and model comparison/selection
- `main.py` — FastAPI app exposing `/predict` and `/retrain`
- `model_utils.py` — model loading/encoding shared by `main.py` and `API/predict.py`
- `API/predict.py` — standalone script for a one-off prediction
- `crop_yield_app/` — Flutter frontend
- `best_model.joblib`, `scaler.joblib`, `feature_columns.joblib` — saved model artifacts produced by `code.ipynb`

## Dataset

`crop_yield.csv` — TODO: add the dataset source link here (Kaggle page, etc). Per-field agricultural records (region, soil type, crop, weather conditions, farming practices) with a continuous target, `Yield_tons_per_hectare`.

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

Live API: **TODO — add the Render URL here once deployed** (Swagger UI at `<url>/docs`).

To deploy:

1. Push this repo to GitHub.
2. On Render: **New → Blueprint**, point it at this repo (picks up `render.yaml`), or **New → Web Service** with:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
3. Once it's live, add the deployed origin to `ALLOWED_ORIGINS` in `main.py` (needed if you deploy the Flutter app to the web too), and point `apiBaseUrl` in `crop_yield_app/lib/main.dart` at the Render URL.

## Flutter app

```bash
cd crop_yield_app
flutter pub get
flutter run -d chrome --web-port=3000
```

`apiBaseUrl` in `lib/main.dart` defaults to `http://127.0.0.1:8000` for local testing against the API above. Point it at the Render URL to use the hosted API instead.
