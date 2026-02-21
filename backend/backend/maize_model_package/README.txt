MAIZE YIELD PREDICTION MODEL
================================

Model Information:
- Best Model: Ensemble (Stacking)
- R² Score: 0.9476
- RMSE: 452.55
- MAE: 357.94
- Number of Features: 20

Files included:
- maize_model/best_model.pkl : Trained model
- maize_model/scaler.pkl : Feature scaler
- maize_model/feature_names.pkl : Feature names list
- maize_model/results.pkl : All model results

How to use:
-----------
import joblib
import numpy as np

# Load model components
model = joblib.load('maize_model/best_model.pkl')
scaler = joblib.load('maize_model/scaler.pkl')
feature_names = joblib.load('maize_model/feature_names.pkl')

# Make prediction
def predict(N, P, K, temp, humidity, ph, rainfall, pesticide):
    # Create features
    features = np.array([[N, P, K, temp, humidity, ph, rainfall, pesticide,
                         N*P, N*K, P*K, temp*rainfall, N**2, P**2, K**2,
                         temp**2, rainfall**2, N+P+K, N/(P+0.001), N/(K+0.001)]])
    features_scaled = scaler.transform(features)
    return model.predict(features_scaled)[0]

# Example
result = predict(100, 50, 60, 25, 65, 6.5, 700, 3)
print(f"Predicted yield: {result:.2f}")
