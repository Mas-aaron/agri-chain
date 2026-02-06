# Supabase Database Design for Agri-Chain Yield Prediction System

## Overview

This database structure supports **HYBRID APPROACH**:
- **Multi-user farm management** (separate farms/fields)
- **Manual data entry** (farmers input data via app UI)
- **IoT sensor data** (automated collection from garden sensors)
- **Weather integration** (forecasts + historical weather APIs)
- **Disease detection results** (from ML model scans)
- **Yield prediction engine** (inputs & outputs)
- **Blockchain integration** (smart contract references)
- **Harvest tracking** (actual yields for model improvement)

### Dual Data Input Paths

**Path A: Manual Entry** → User enters data through app UI → Database → Yield Engine  
**Path B: Automated** → IoT Sensors/Weather API → Database → Yield Engine  
**Hybrid**: Combine both sources for more accurate predictions

---

## Database Architecture

### Core Data Flow

```
IoT Sensors → sensor_readings
              ↓
         sensor_readings + weather_data + field_data
              ↓
      → Yield Prediction Engine
              ↓
      yield_predictions (stored in DB)
              ↓
         harvest_data (actual vs predicted)
              ↓
      Model improvement feedback loop
```

---

## Data Entry Modes

### **Mode 1: Manual Entry (No IoT)**
Perfect for farmers without sensor hardware. Enter data manually through app:
- Daily field observations (soil moisture, plant height, color)
- Manual weather readings (temperature, rainfall measured locally)
- Operational logs (fertilizer applied, pesticide sprayed, irrigation duration)
- Disease/pest observations (visual inspection)

### **Mode 2: Automated Sensors (Full IoT)**
For farms with deployed sensors:
- Continuous sensor readings (temperature, humidity, soil moisture)
- Automated weather data from APIs
- Timestamp-based data collection

### **Mode 3: Hybrid (Best Accuracy)**
Combination of both:
- Sensors provide baseline continuous data
- Users fill gaps with manual observations
- App suggests data points based on what's missing

---

## Table Schemas & Relationships

### 1. **users**
Stores user/farm owner information.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  farm_company_name TEXT,
  phone TEXT,
  country TEXT,
  region TEXT,
  profile_picture_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- Index for quick lookups
CREATE INDEX idx_users_email ON users(email);
```

**Purpose**: Authentication & basic farm owner info

---

### 2. **farms**
Groups fields/plots owned by a user.

```sql
CREATE TABLE farms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  farm_name TEXT NOT NULL,
  location_latitude DECIMAL(10, 8),
  location_longitude DECIMAL(11, 8),
  total_area_hectares DECIMAL(10, 2),
  soil_type TEXT, -- e.g., "loamy", "clay", "sandy"
  climate_zone TEXT, -- e.g., "tropical", "temperate", "arid"
  country TEXT,
  region TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_farms_user_id ON farms(user_id);
CREATE INDEX idx_farms_location ON farms(location_latitude, location_longitude);
```

**Purpose**: Group multiple fields; store geographic & soil info

---

### 3. **fields**
Individual plots/fields within a farm.

```sql
CREATE TABLE fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  field_code TEXT UNIQUE, -- e.g., "FARM-001-FIELD-A"
  area_hectares DECIMAL(10, 2),
  location_latitude DECIMAL(10, 8),
  location_longitude DECIMAL(11, 8),
  soil_ph DECIMAL(3, 1),
  soil_nitrogen_ppm DECIMAL(8, 2),
  soil_phosphorus_ppm DECIMAL(8, 2),
  soil_potassium_ppm DECIMAL(8, 2),
  elevation_meters INT,
  field_status TEXT DEFAULT 'active', -- active, fallow, archived
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fields_farm_id ON fields(farm_id);
CREATE INDEX idx_fields_status ON fields(field_status);
```

**Purpose**: Store individual field/plot data with soil composition

---

### 4. **plantings**
Tracks what crop is planted in each field and when.

```sql
CREATE TABLE plantings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  crop_type TEXT NOT NULL, -- e.g., "maize", "wheat", "rice"
  crop_variety TEXT, -- e.g., "Golden_Bantam", "Dent_Corn"
  planting_date DATE NOT NULL,
  expected_harvest_date DATE,
  planting_density INT, -- seeds per hectare
  seed_rate_kg_per_hectare DECIMAL(8, 2),
  expected_yield_kg_per_hectare DECIMAL(10, 2), -- baseline expectation
  irrigation_type TEXT, -- e.g., "drip", "furrow", "flood", "rain-fed"
  fertilizer_schedule TEXT, -- JSON or reference to fertilizer_applications
  pesticide_schedule TEXT, -- JSON or reference to pesticide_applications
  notes TEXT,
  status TEXT DEFAULT 'active', -- active, harvested, abandoned
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_plantings_field_id ON plantings(field_id);
CREATE INDEX idx_plantings_crop_type ON plantings(crop_type);
CREATE INDEX idx_plantings_status ON plantings(status);
```

**Purpose**: Track planting cycles; enables prediction per planting season

---

### 5. **sensors**
IoT sensor devices in the garden.

```sql
CREATE TABLE sensors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  sensor_name TEXT NOT NULL,
  sensor_type TEXT NOT NULL, -- e.g., "temperature", "humidity", "soil_moisture", 
                              -- "soil_temp", "wind_speed", "rainfall", "ph_sensor"
  sensor_model TEXT, -- e.g., "DHT22", "Capacitive_Soil_Moisture"
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  installation_date DATE,
  battery_status TEXT, -- "good", "low", "critical"
  last_reading_at TIMESTAMP,
  sensor_status TEXT DEFAULT 'active', -- active, inactive, broken
  unit_of_measurement TEXT, -- e.g., "°C", "%", "mm", "m/s"
  min_reading_threshold DECIMAL(10, 2), -- for alerts
  max_reading_threshold DECIMAL(10, 2), -- for alerts
  metadata JSONB, -- Additional sensor-specific info
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sensors_field_id ON sensors(field_id);
CREATE INDEX idx_sensors_type ON sensors(sensor_type);
CREATE INDEX idx_sensors_status ON sensors(sensor_status);
```

**Purpose**: Catalog all IoT sensors; manage connectivity & thresholds

---

### 6. **sensor_readings**
Time-series sensor data (HIGH VOLUME TABLE).

```sql
CREATE TABLE sensor_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sensor_id UUID NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
  reading_value DECIMAL(10, 4) NOT NULL,
  reading_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  battery_voltage DECIMAL(5, 2), -- optional
  signal_strength INT, -- optional, e.g., WiFi RSSI (-100 to 0 dBm)
  data_quality_flag TEXT, -- "good", "interpolated", "estimated"
  
  -- Track data source (HYBRID SUPPORT)
  data_source TEXT DEFAULT 'sensor', -- "sensor", "manual_entry", "api", "imported"
  entered_by UUID REFERENCES users(id), -- if manual entry, who entered it
  entry_notes TEXT, -- if manual, notes from user
  
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- CRITICAL: Add partitioning by month for performance with large datasets
-- CREATE TABLE sensor_readings_2024_01 PARTITION OF sensor_readings
--   FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Indexes for common queries
CREATE INDEX idx_sensor_readings_sensor_id ON sensor_readings(sensor_id);
CREATE INDEX idx_sensor_readings_timestamp ON sensor_readings(reading_timestamp DESC);
CREATE INDEX idx_sensor_readings_composite ON sensor_readings(sensor_id, reading_timestamp DESC);
CREATE INDEX idx_sensor_readings_data_source ON sensor_readings(data_source); -- for analytics

-- Retention policy: Keep 2 years of detailed data, archive older data
-- Consider using Timescale extension for hypertables if using heavily
```

**Purpose**: Store IoT sensor data AND manual field observations; hybrid tracking

---

### 7. **weather_data**
Weather forecasts, historical weather, and manual weather observations.

```sql
CREATE TABLE weather_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  weather_date DATE NOT NULL,
  weather_time TIME, -- can be NULL for daily forecasts
  weather_timestamp TIMESTAMP,
  
  -- Temperature
  temperature_celsius DECIMAL(5, 2),
  min_temperature_celsius DECIMAL(5, 2),
  max_temperature_celsius DECIMAL(5, 2),
  feels_like_celsius DECIMAL(5, 2),
  
  -- Humidity & Pressure
  humidity_percent DECIMAL(5, 2),
  atmospheric_pressure_hpa DECIMAL(8, 2),
  dew_point_celsius DECIMAL(5, 2),
  
  -- Precipitation
  rainfall_mm DECIMAL(8, 2),
  rainfall_probability_percent INT,
  
  -- Wind
  wind_speed_kmh DECIMAL(6, 2),
  wind_gust_kmh DECIMAL(6, 2),
  wind_direction_degrees INT, -- 0-360
  
  -- Radiation & Clouds
  solar_radiation_w_per_m2 DECIMAL(8, 2),
  cloud_coverage_percent INT,
  visibility_km DECIMAL(8, 2),
  
  -- Classification
  weather_condition TEXT, -- e.g., "sunny", "cloudy", "rainy", "snowy"
  weather_description TEXT,
  
  -- Data source tracking (HYBRID SUPPORT)
  data_source TEXT DEFAULT 'openweathermap', -- "openweathermap", "weatherapi", "manual_observation", "sensor"
  is_forecast BOOLEAN DEFAULT FALSE, -- TRUE for forecast, FALSE for historical
  forecast_date TIMESTAMP, -- when forecast was made
  
  -- Manual entry tracking
  entered_by UUID REFERENCES users(id), -- if manual, who entered it
  entry_confidence TEXT DEFAULT 'high', -- "high", "medium", "low" (for manual entries)
  entry_notes TEXT,
  
  data_completeness_percent INT DEFAULT 100, -- % of fields populated
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_weather_field_id ON weather_data(field_id);
CREATE INDEX idx_weather_date ON weather_data(weather_date);
CREATE INDEX idx_weather_timestamp ON weather_data(weather_timestamp DESC);
CREATE INDEX idx_weather_composite ON weather_data(field_id, weather_date DESC);
CREATE INDEX idx_weather_data_source ON weather_data(data_source);
```

**Purpose**: Store weather data from APIs, forecasts, and manual observations

---

### 8. **field_observations**
Manual observations entered by farmers (plants, soil, pests, diseases).

```sql
CREATE TABLE field_observations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  planting_id UUID REFERENCES plantings(id) ON DELETE SET NULL,
  
  observation_date DATE NOT NULL,
  observation_time TIME,
  observed_by UUID NOT NULL REFERENCES users(id), -- farmer who observed
  
  -- Plant health observations
  plant_height_cm DECIMAL(8, 2),
  leaf_color TEXT, -- e.g., "green", "yellow", "purple", "brown"
  leaf_health_percent INT, -- % of healthy leaves (0-100)
  flowering_stage BOOLEAN,
  stem_condition TEXT, -- e.g., "healthy", "bent", "broken"
  
  -- Soil observations (manual)
  soil_moisture_visual TEXT, -- "dry", "moist", "wet"
  soil_color TEXT,
  soil_compaction TEXT, -- "low", "moderate", "high"
  
  -- Pest/Disease observations
  pest_name TEXT, -- e.g., "armyworm", "grasshopper"
  pest_count_per_10_plants INT,
  pest_damage_visible BOOLEAN,
  pest_damage_percent DECIMAL(5, 2),
  
  disease_observed BOOLEAN,
  disease_name TEXT,
  disease_severity TEXT, -- "mild", "moderate", "severe"
  affected_plants_percent DECIMAL(5, 2),
  
  -- Environmental
  weather_at_observation TEXT,
  wind_condition TEXT, -- "calm", "light", "moderate", "strong"
  
  -- Action taken
  action_recommended TEXT,
  action_taken BOOLEAN DEFAULT FALSE,
  action_description TEXT,
  
  -- Photo
  photo_url TEXT,
  photo_notes TEXT,
  
  confidence_level TEXT DEFAULT 'medium', -- "low", "medium", "high"
  notes TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_field_observations_field_id ON field_observations(field_id);
CREATE INDEX idx_field_observations_date ON field_observations(observation_date);
CREATE INDEX idx_field_observations_planting_id ON field_observations(planting_id);
```

**Purpose**: Store manual field observations from farmers (no sensors needed)

---

### 9. **manual_irrigation_logs**
Specifically for farmers to log irrigation manually (when no sensor).

```sql
CREATE TABLE manual_irrigation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  planting_id UUID REFERENCES plantings(id) ON DELETE SET NULL,
  
  irrigation_date DATE NOT NULL,
  irrigation_start_time TIME,
  irrigation_duration_hours DECIMAL(6, 2),
  irrigation_method TEXT, -- "drip", "flood", "sprinkler", "furrow", "manual_watering"
  water_source TEXT, -- "well", "borehole", "canal", "rainwater_tank"
  
  -- Amount of water
  volume_liters DECIMAL(12, 2), -- if known
  estimated_rainfall_equivalent_mm DECIMAL(8, 2), -- farmer's estimate
  
  -- Soil response
  soil_moisture_before TEXT, -- "dry", "moist", "wet"
  soil_moisture_after TEXT,
  runoff_observed BOOLEAN,
  
  recorded_by UUID NOT NULL REFERENCES users(id),
  notes TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_irrigation_logs_field_id ON manual_irrigation_logs(field_id);
CREATE INDEX idx_irrigation_logs_date ON manual_irrigation_logs(irrigation_date);
```

**Purpose**: Dedicated table for manual irrigation logging

---

### 10. **disease_scans**
Results from ML disease detection model.

```sql
CREATE TABLE disease_scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  planting_id UUID REFERENCES plantings(id) ON DELETE SET NULL,
  scan_date TIMESTAMP NOT NULL DEFAULT NOW(),
  scan_latitude DECIMAL(10, 8),
  scan_longitude DECIMAL(11, 8),
  
  -- Image data
  image_path TEXT,
  image_url TEXT,
  image_hash TEXT, -- to detect duplicates
  
  -- ML Model results
  model_version TEXT, -- e.g., "v1.0", "v2.1"
  detected_disease TEXT, -- e.g., "Northern_Leaf_Blight", "Gray_Leaf_Spot", "None"
  confidence_score DECIMAL(5, 4), -- 0.0 to 1.0
  disease_severity TEXT, -- "none", "mild", "moderate", "severe"
  affected_area_percent DECIMAL(5, 2), -- % of leaf/plant affected
  
  -- Additional detections (if model detects multiple issues)
  additional_observations JSONB, -- e.g., [{"pest": "armyworm", "confidence": 0.92}]
  
  -- Recommended action
  recommended_treatment TEXT,
  treatment_urgency TEXT, -- "low", "medium", "high", "critical"
  
  -- Farmer follow-up
  treatment_applied BOOLEAN DEFAULT FALSE,
  treatment_applied_date TIMESTAMP,
  treatment_details TEXT,
  treatment_effectiveness TEXT, -- "not_checked", "failed", "partial", "successful"
  
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_disease_scans_field_id ON disease_scans(field_id);
CREATE INDEX idx_disease_scans_date ON disease_scans(scan_date DESC);
CREATE INDEX idx_disease_scans_disease ON disease_scans(detected_disease);
```

**Purpose**: Store ML detection results; input to yield prediction model

---

### 11. **yield_predictions**
Output from yield prediction engine.

```sql
CREATE TABLE yield_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  planting_id UUID NOT NULL REFERENCES plantings(id) ON DELETE CASCADE,
  
  -- Prediction metadata
  prediction_date TIMESTAMP NOT NULL DEFAULT NOW(),
  prediction_days_to_harvest INT, -- days until predicted harvest
  
  -- Prediction values
  predicted_yield_kg_per_hectare DECIMAL(10, 2),
  confidence_score DECIMAL(5, 4), -- 0.0 to 1.0 (how confident the model is)
  
  -- Yield band (risk categorization)
  yield_band TEXT, -- "very_low", "low", "medium", "high", "very_high"
  yield_band_min_kg_per_hectare DECIMAL(10, 2),
  yield_band_max_kg_per_hectare DECIMAL(10, 2),
  
  -- Economic prediction
  estimated_revenue_usd DECIMAL(15, 2), -- based on market price
  estimated_production_cost_usd DECIMAL(15, 2),
  estimated_profit_usd DECIMAL(15, 2),
  market_price_usd_per_kg DECIMAL(10, 2), -- price used for calculation
  
  -- Risk factors identified
  risk_factors JSONB, -- e.g., [{"factor": "disease_detected", "impact": -15}, {"factor": "low_rainfall", "impact": -20}]
  
  -- Model inputs used (for traceability)
  model_version TEXT,
  features_used JSONB, -- list of input features
  
  -- Recommendations
  recommendations TEXT[],
  
  -- Prediction status
  is_current BOOLEAN DEFAULT TRUE, -- latest prediction for this planting
  prediction_status TEXT DEFAULT 'active', -- active, invalidated, harvested
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_yield_predictions_field_id ON yield_predictions(field_id);
CREATE INDEX idx_yield_predictions_planting_id ON yield_predictions(planting_id);
CREATE INDEX idx_yield_predictions_date ON yield_predictions(prediction_date DESC);
CREATE INDEX idx_yield_predictions_current ON yield_predictions(is_current) WHERE is_current = TRUE;
```

**Purpose**: Store yield engine outputs; core table for predictions

---

### 12. **harvest_data**
Actual harvest results (for model validation & improvement).

```sql
CREATE TABLE harvest_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  planting_id UUID NOT NULL REFERENCES plantings(id) ON DELETE CASCADE,
  
  -- Harvest details
  harvest_date DATE NOT NULL,
  harvest_time TIME,
  total_harvest_kg DECIMAL(15, 2),
  yield_kg_per_hectare DECIMAL(10, 2),
  
  -- Quality metrics
  grain_moisture_percent DECIMAL(5, 2), -- for maize, corn
  test_weight_kg_per_bushel DECIMAL(6, 2), -- for maize
  damaged_grain_percent DECIMAL(5, 2),
  foreign_material_percent DECIMAL(5, 2),
  grade TEXT, -- e.g., "Grade A", "Grade B"
  
  -- Market data
  market_price_usd_per_kg DECIMAL(10, 2),
  total_revenue_usd DECIMAL(15, 2),
  
  -- Comparison with prediction
  yield_prediction_id UUID REFERENCES yield_predictions(id) ON DELETE SET NULL,
  predicted_yield_kg_per_hectare DECIMAL(10, 2), -- from linked prediction
  yield_variance_percent DECIMAL(8, 2), -- (actual - predicted) / predicted * 100
  
  -- Conditions at harvest
  weather_at_harvest TEXT,
  disease_present_at_harvest TEXT,
  pest_damage_percent DECIMAL(5, 2),
  other_losses_percent DECIMAL(5, 2),
  
  -- Notes
  harvested_by TEXT,
  notes TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_harvest_data_field_id ON harvest_data(field_id);
CREATE INDEX idx_harvest_data_planting_id ON harvest_data(planting_id);
CREATE INDEX idx_harvest_data_date ON harvest_data(harvest_date DESC);
CREATE INDEX idx_harvest_data_prediction_id ON harvest_data(yield_prediction_id);
```

**Purpose**: Store actual harvest; compare vs predictions for model improvement

---

### 13. **blockchain_references**
Links to smart contract transactions.

```sql
CREATE TABLE blockchain_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE,
  field_id UUID REFERENCES fields(id) ON DELETE CASCADE,
  harvest_id UUID REFERENCES harvest_data(id) ON DELETE CASCADE,
  
  -- Smart contract references
  contract_type TEXT, -- "AgriAssetRegistry", "AgriLoanMarket", "AgriYieldToken"
  contract_address TEXT,
  transaction_hash TEXT UNIQUE,
  block_number BIGINT,
  
  -- Blockchain event
  event_type TEXT, -- e.g., "asset_registered", "loan_offered", "yield_tokenized"
  event_data JSONB,
  
  -- Verification
  is_verified BOOLEAN DEFAULT FALSE,
  verification_date TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_blockchain_farm_id ON blockchain_references(farm_id);
CREATE INDEX idx_blockchain_tx_hash ON blockchain_references(transaction_hash);
```

**Purpose**: Track blockchain integration for AgriAssetRegistry, AgriLoanMarket, AgriYieldToken

---

### 14. **ml_model_logs**
Track yield prediction model training & performance.

```sql
CREATE TABLE ml_model_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version TEXT NOT NULL, -- e.g., "v1.0", "v2.1"
  model_type TEXT, -- "random_forest", "neural_network", "xgboost"
  
  -- Training info
  training_date TIMESTAMP,
  training_data_samples INT, -- how many harvest records used
  training_crops TEXT[], -- crops trained on: ["maize", "wheat"]
  
  -- Model performance
  mae_kg_per_hectare DECIMAL(10, 2), -- Mean Absolute Error
  rmse_kg_per_hectare DECIMAL(10, 2), -- Root Mean Squared Error
  r_squared DECIMAL(5, 4), -- R² coefficient
  
  -- Deployment info
  is_active BOOLEAN DEFAULT FALSE,
  deployed_date TIMESTAMP,
  deployment_notes TEXT,
  
  -- Feature importance (if available)
  feature_importance JSONB, -- {"rainfall": 0.25, "temperature": 0.20, ...}
  
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ml_model_logs_version ON ml_model_logs(model_version);
CREATE INDEX idx_ml_model_logs_active ON ml_model_logs(is_active);
```

**Purpose**: Track model versions, performance, and deployment history

---

## Hybrid Data Entry Architecture

### How It Works: Manual + Automated Together

```
SCENARIO 1: Fully Automated (With Sensors)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IoT Sensors (temperature, humidity, soil moisture)
    ↓ (auto-upload)
sensor_readings (data_source = 'sensor')
    ↓
Weather API (openweathermap)
    ↓ (auto-fetch daily)
weather_data (data_source = 'openweathermap', is_forecast = FALSE)
    ↓
Yield Prediction Engine
    ↓
yield_predictions (accurate & continuous)

SCENARIO 2: Fully Manual (No Sensors)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Farmer Opens App Daily
    ↓
enters: temperature, plant height, disease observations
    ↓
field_observations table
manual_weather_data (weather_data with data_source = 'manual_observation')
manual_irrigation_logs
    ↓
Yield Prediction Engine (with fewer features)
    ↓
yield_predictions (lower confidence, but still useful)

SCENARIO 3: Hybrid (Best Accuracy)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sensors provide baseline continuous data
    +
Farmer fills gaps with observations (disease, pest signs)
    +
Weather API provides complete data
    ↓
Combined dataset
    ↓
Yield Prediction Engine (very accurate)
    ↓
yield_predictions (highest confidence)
```

### Data Source Tracking

All data tables track `data_source` and entry metadata:

| Field | Values | Purpose |
|-------|--------|---------|
| `data_source` | 'sensor', 'manual_entry', 'api', 'imported' | Where data came from |
| `entered_by` | UUID to users | Who manually entered it |
| `entry_confidence` | 'low', 'medium', 'high' | Confidence in data quality |
| `entry_notes` | TEXT | Why data is missing or unusual |
| `entry_timestamp` | TIMESTAMP | When entered into app |
| `data_completeness_percent` | INT (0-100) | % of fields populated |

### Yield Prediction Engine Strategy

The prediction engine adjusts based on data availability:

```json
{
  "prediction_mode": "auto-determine",
  "available_data": {
    "has_sensor_data": true,
    "has_weather_data": true,
    "has_manual_observations": true,
    "data_completeness_percent": 95
  },
  "model_selection": "full_precision_model",
  "confidence_multiplier": 1.0,
  "notes": "All data available, using primary model"
}
```

### App UI Logic for Data Entry

**When farmer opens app:**

1. **Check field data completeness:**
   ```
   IF field has sensors:
     → Show sensor data dashboard (auto-refreshing)
   ELSE:
     → Show manual entry forms
   ```

2. **Suggest missing data:**
   ```
   IF last_manual_observation > 3 days ago:
     → Notify user: "Please add field observations"
   
   IF no irrigation logged this week:
     → Notify user: "Log your irrigation for yield accuracy"
   ```

3. **Combine data for predictions:**
   ```
   SELECT 
     sensor_readings,
     weather_data,
     field_observations,
     manual_irrigation_logs,
     field_operations
   FROM all_tables
   WHERE field_id = $1 AND timestamp > (NOW() - 30 DAYS)
   → Feed to Yield Engine
   ```

---

## Relationships Diagram

## Relationships Diagram

```
users (1) ──→ (many) farms
  ↓
farms (1) ──→ (many) fields
  ↓
fields (1) ──→ (many) plantings
fields (1) ──→ (many) sensors ↔ sensor_readings (automated)
fields (1) ──→ (many) field_observations (manual)
fields (1) ──→ (many) manual_irrigation_logs (manual)
fields (1) ──→ (many) weather_data (API + manual)
fields (1) ──→ (many) disease_scans (ML)
fields (1) ──→ (many) field_operations (logs)
  ↓
plantings (1) ──→ (many) yield_predictions ← [COMBINES ALL DATA]
plantings (1) ──→ (many) harvest_data

yield_predictions ←→ harvest_data (comparison)
harvest_data ←→ blockchain_references
farms ←→ blockchain_references
```

---

## Row Level Security (RLS) Policy Examples

### Farmers can only see their own data

```sql
-- For farms table
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own farms"
  ON farms FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own farms"
  ON farms FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own farms"
  ON farms FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Similar policies for fields, sensor_readings, etc.
```

---

## Sample Queries for Yield Prediction Engine

### 1. Get all sensor data for a field in last 7 days

```sql
SELECT 
  s.sensor_name,
  s.sensor_type,
  sr.reading_value,
  sr.reading_timestamp
FROM sensor_readings sr
JOIN sensors s ON sr.sensor_id = s.id
WHERE s.field_id = $1
  AND sr.reading_timestamp > NOW() - INTERVAL '7 days'
ORDER BY sr.reading_timestamp DESC;
```

### 2. Get weather data for yield prediction

```sql
SELECT 
  weather_date,
  temperature_celsius,
  rainfall_mm,
  humidity_percent,
  wind_speed_kmh,
  solar_radiation_w_per_m2
FROM weather_data
WHERE field_id = $1
  AND weather_date >= $2
  AND is_forecast = FALSE
ORDER BY weather_date;
```

### 3. Get field operations impact on yield

```sql
SELECT 
  operation_type,
  operation_date,
  CASE 
    WHEN operation_type = 'fertilizer' THEN fertilizer_npk
    WHEN operation_type = 'pesticide' THEN pesticide_name
    WHEN operation_type = 'irrigation' THEN irrigation_amount_mm::TEXT
  END as operation_details
FROM field_operations
WHERE field_id = $1
  AND planting_id = $2
ORDER BY operation_date;
```

### 4. Get disease progression for a planting

```sql
SELECT 
  scan_date,
  detected_disease,
  confidence_score,
  disease_severity,
  affected_area_percent
FROM disease_scans
WHERE planting_id = $1
ORDER BY scan_date;
```

### 5. Compare prediction vs actual harvest

```sql
SELECT 
  yp.predicted_yield_kg_per_hectare,
  hd.yield_kg_per_hectare,
  hd.yield_variance_percent,
  yp.confidence_score,
  yp.model_version
FROM yield_predictions yp
JOIN harvest_data hd ON yp.id = hd.yield_prediction_id
WHERE yp.field_id = $1
ORDER BY hd.harvest_date DESC;
```

### 6. Feature set for yield prediction (comprehensive)

```sql
WITH field_data AS (
  SELECT 
    f.id,
    f.soil_nitrogen_ppm,
    f.soil_phosphorus_ppm,
    f.soil_potassium_ppm,
    f.soil_ph
  FROM fields f
  WHERE f.id = $1
),
weather_avg AS (
  SELECT 
    AVG(temperature_celsius) as avg_temp,
    AVG(rainfall_mm) as total_rainfall,
    AVG(humidity_percent) as avg_humidity,
    MAX(solar_radiation_w_per_m2) as max_solar_radiation
  FROM weather_data
  WHERE field_id = $1
    AND weather_date >= $2
    AND is_forecast = FALSE
),
sensor_avg AS (
  SELECT 
    s.sensor_type,
    AVG(sr.reading_value) as avg_reading
  FROM sensor_readings sr
  JOIN sensors s ON sr.sensor_id = s.id
  WHERE s.field_id = $1
    AND sr.reading_timestamp >= NOW() - INTERVAL '30 days'
  GROUP BY s.sensor_type
),
disease_risk AS (
  SELECT 
    COALESCE(SUM(confidence_score), 0) as disease_risk_score
  FROM disease_scans
  WHERE field_id = $1
    AND planting_id = $3
),
operations_count AS (
  SELECT 
    SUM(CASE WHEN operation_type = 'fertilizer' THEN 1 ELSE 0 END) as fertilizer_apps,
    SUM(CASE WHEN operation_type = 'irrigation' THEN 1 ELSE 0 END) as irrigation_apps,
    SUM(CASE WHEN operation_type = 'pesticide' THEN 1 ELSE 0 END) as pesticide_apps
  FROM field_operations
  WHERE field_id = $1 AND planting_id = $3
)
SELECT 
  fd.soil_nitrogen_ppm,
  fd.soil_phosphorus_ppm,
  fd.soil_potassium_ppm,
  fd.soil_ph,
  wa.avg_temp,
  wa.total_rainfall,
  wa.avg_humidity,
  wa.max_solar_radiation,
  oc.fertilizer_apps,
  oc.irrigation_apps,
  oc.pesticide_apps,
  dr.disease_risk_score
FROM field_data fd
CROSS JOIN weather_avg wa
CROSS JOIN disease_risk dr
CROSS JOIN operations_count oc;
```

---

## Indexes Strategy

### High-Priority Indexes (for performance)

```sql
-- Time-series queries (most common)
CREATE INDEX idx_sensor_readings_time_series 
  ON sensor_readings(sensor_id, reading_timestamp DESC);

CREATE INDEX idx_weather_data_time_series 
  ON weather_data(field_id, weather_date DESC);

-- User isolation (RLS)
CREATE INDEX idx_farms_by_user 
  ON farms(user_id);

-- Prediction lookups
CREATE INDEX idx_yield_predictions_current 
  ON yield_predictions(field_id, is_current);

-- Harvest comparisons
CREATE INDEX idx_harvest_vs_prediction 
  ON harvest_data(yield_prediction_id);
```

---

## Data Volume Estimates

| Table | Monthly Growth | 1-Year Total | 5-Year Total |
|-------|---------|---------|---------|
| sensor_readings | 2-5M rows/field | 24-60M | 120-300M |
| weather_data | 1-2K rows/field | 5-10K | 25-50K |
| yield_predictions | 100-200/farm | 1-2K | 5-10K |
| harvest_data | 50-100/farm | 500-1K | 2.5-5K |
| disease_scans | 100-500/field | 1-5K | 5-25K |

**Note**: sensor_readings grows fastest; implement partitioning for scalability

---

## Migration from SharedPreferences to Supabase

Current local storage (SharedPreferences):
```dart
// Current: local only
_selectedFieldId = prefs.getString('agri_chain_scan_selected_field_v1');
```

Migrate to:
```dart
// New: Supabase
final response = await Supabase.instance.client
  .from('plantings')
  .select('*')
  .eq('field_id', fieldId)
  .order('planting_date', ascending: false)
  .single();
```

Benefits:
- ✅ Real-time sync across devices
- ✅ Centralized data for yield engine
- ✅ Supports collaborative farming
- ✅ Historical data for model training

---

## Implementation Priority

**Phase 1 (MVP)**: `users`, `farms`, `fields`, `plantings`, `sensors`, `sensor_readings`, `weather_data`

**Phase 2**: `disease_scans`, `field_operations`, `yield_predictions`, `harvest_data`

**Phase 3**: `blockchain_references`, `ml_model_logs`

---

## References & Resources

- [Supabase PostgreSQL Docs](https://supabase.com/docs/guides/database)
- [Time-Series Data Best Practices](https://www.postgresql.org/docs/current/sql-createindex.html)
- [TimescaleDB (optional extension for sensor data)](https://www.timescale.com/)
- [PostGIS (if adding geospatial queries)](https://postgis.net/)

---

**Next Steps**:
1. Create Supabase project
2. Run SQL scripts to create tables
3. Set up RLS policies
4. Configure backups & retention
5. Load sample data for testing
6. Build yield prediction queries
