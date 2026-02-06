# Visual Architecture & Data Flow Summary

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     AGRI-CHAIN HYBRID SYSTEM                    │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │    SUPABASE      │
                    │   PostgreSQL     │
                    │     Cloud        │
                    └──────────────────┘
                            ▲
                ┌───────────┼───────────┐
                │           │           │
         ┌──────▼────┐  ┌──▼───────┐  ┌──────▼─────┐
         │   IoT     │  │ Weather  │  │   Farmer  │
         │ Sensors   │  │   API    │  │   Manual  │
         │           │  │          │  │   Entry   │
         └───────────┘  └──────────┘  └───────────┘
              │              │              │
    ┌─────────▼──────────────▼──────────────▼────────┐
    │    SENSOR_READINGS   WEATHER_DATA   MANUAL     │
    │    OBSERVATIONS      IRRIGATION     LOGS       │
    └──────────────┬────────────────────────────────┘
                   │
                   ▼
    ┌──────────────────────────────────┐
    │   YIELD PREDICTION ENGINE        │
    │                                  │
    │  - Aggregates all data           │
    │  - Calculates confidence scores  │
    │  - Identifies risk factors       │
    │  - Makes predictions             │
    └──────────────┬───────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │ YIELD_PREDICTIONS   │
         │ (Stored in DB)      │
         │                     │
         │ - predicted_yield   │
         │ - confidence_score  │
         │ - risk_factors      │
         │ - recommendations   │
         └─────────┬───────────┘
                   │
                   ▼
          ┌────────────────────┐
          │  FLUTTER APP UI    │
          │                    │
          │ - Show prediction  │
          │ - Alert warnings   │
          │ - Data entry forms │
          │ - Reports          │
          └────────────────────┘
```

---

## Data Entry Modes

### Mode 1: FULLY AUTOMATED
```
         ┌─────────────────┐
         │   IoT SENSORS   │
         │                 │
         │ • Temperature   │
         │ • Humidity      │
         │ • Soil Moisture │
         │ • Wind Speed    │
         └────────┬────────┘
                  │
              Every 15 min
                  │
         ┌────────▼────────┐
         │  SENSOR_READINGS│ ──────┐
         │  (1440/day)     │       │
         └─────────────────┘       │
                                   │
         ┌──────────────────────┐  │
         │   WEATHER API        │  │
         │                      │  │
         │ (openweathermap)     │  │
         └────────┬─────────────┘  │
                  │                │
              Daily               │
                  │                │
         ┌────────▼────────┐      │
         │  WEATHER_DATA   │◄─────┘
         │  (data_source=  │
         │   'api')        │
         └────────┬────────┘
                  │
       ┌──────────▼──────────┐
       │ YIELD ENGINE GETS:  │
       │                     │
       │ ✓ Hourly temps      │
       │ ✓ Continuous soil   │
       │ ✓ Daily weather     │
       │ ✓ High confidence   │
       │ ✓ Low user effort   │
       └─────────────────────┘
```

### Mode 2: FULLY MANUAL
```
    ┌─────────────────────────────┐
    │  FARMER OPENS APP DAILY     │
    │                             │
    │ "Good morning! Let's log    │
    │  today's field conditions"  │
    └────────────┬────────────────┘
                 │
    ┌────────────▼────────────┐
    │  WEATHER ENTRY FORM     │
    │                         │
    │ • Temperature: 22°C     │
    │ • Humidity: 65%         │
    │ • Rainfall: 0mm         │
    │ • Condition: sunny      │
    │ • Wind: 5 km/h          │
    │ • Confidence: medium    │
    └────────────┬────────────┘
                 │
         ┌───────▼────────┐
         │MANUAL_WEATHER  │
         │(data_source=   │
         │'manual')       │
         └────────┬───────┘
                  │
    ┌─────────────▼─────────────┐
    │ FIELD OBSERVATION FORM    │
    │                           │
    │ • Plant height: 45cm      │
    │ • Leaf color: green       │
    │ • Soil moisture: moist    │
    │ • Pest observed? no       │
    │ • Disease? no             │
    │ • Confidence: high        │
    └─────────────┬─────────────┘
                  │
    ┌─────────────▼──────────────┐
    │FIELD_OBSERVATIONS         │
    │(manual data entry)         │
    └─────────────┬──────────────┘
                  │
    ┌─────────────▼──────────────┐
    │ IRRIGATION LOG FORM        │
    │                            │
    │ • Duration: 30 min         │
    │ • Method: drip             │
    │ • Soil before: dry         │
    │ • Soil after: moist        │
    │ • Est. water: 15mm         │
    └─────────────┬──────────────┘
                  │
    ┌─────────────▼──────────────┐
    │MANUAL_IRRIGATION_LOGS      │
    │(manual data entry)         │
    └─────────────┬──────────────┘
                  │
       ┌──────────▼──────────┐
       │ YIELD ENGINE GETS:  │
       │                     │
       │ ✓ Daily weather     │
       │ ✓ Plant health      │
       │ ✓ Water applied     │
       │ ✓ Medium confidence │
       │ ✓ ~15 min/day work  │
       └─────────────────────┘
```

### Mode 3: HYBRID (BEST)
```
                SENSORS                MANUAL INPUT
                 (24/7)                (Daily form)
                   │                        │
        ┌──────────▼──────────┐  ┌──────────▼──────────┐
        │ SENSOR_READINGS:    │  │ FIELD_OBSERVATIONS │
        │                     │  │ IRRIGATION_LOGS     │
        │ • 1440 records/day  │  │ WEATHER_MANUAL      │
        │ • Continuous        │  │                     │
        │ • Precise           │  │ • 1 entry/day      │
        │ • Real-time         │  │ • Detailed views   │
        │ • Cost $$           │  │ • Disease signs    │
        └──────────┬──────────┘  └──────────┬─────────┘
                   │                        │
                   └────────────┬───────────┘
                                │
                    ┌───────────▼──────────┐
                    │  WEATHER API         │
                    │  (Daily forecasts)   │
                    └───────────┬──────────┘
                                │
                    ┌───────────▼──────────┐
                    │ COMBINED DATA:       │
                    │                      │
                    │ • Hourly temps       │
                    │ • Daily observations │
                    │ • Water applied      │
                    │ • Pest monitoring    │
                    │ • Full coverage      │
                    │ • HIGHEST CONF 0.98  │
                    └───────────┬──────────┘
                                │
                    ┌───────────▼──────────┐
                    │ YIELD PREDICTION:    │
                    │                      │
                    │ • Most accurate      │
                    │ • Best confidence    │
                    │ • Complete picture   │
                    │ • Optimized                │
                    │   recommendations   │
                    └──────────────────────┘
```

---

## Database Schema (15 Tables)

```
                        ┌─────────────┐
                        │   USERS     │
                        └──────┬──────┘
                               │ 1:N
                        ┌──────▼──────┐
                        │    FARMS    │
                        └──────┬──────┘
                               │ 1:N
        ┌──────────────────────▼──────────────────────┐
        │             FIELDS                          │
        └─┬────────────────┬─────────────────────┬───┘
          │                │                     │
        1:N              1:N                    1:N
          │                │                     │
    ┌─────▼────┐    ┌──────▼──────┐      ┌─────▼──────┐
    │ PLANTINGS │    │  SENSORS    │      │ WEATHER_   │
    └─────┬────┘    │             │      │ DATA       │
          │         └──────┬──────┘      └────────────┘
        1:N               1:N
          │                │
          │        ┌───────▼──────────┐
          │        │ SENSOR_READINGS  │ (24/7 data stream)
          │        └──────────────────┘
          │
    ┌─────┴──────────────────────────────────────────────────────┐
    │                                                              │
  1:N                                                            1:N
    │                                                              │
┌───▼────────┐     ┌──────────────────┐    ┌────────────────────┐
│FIELD_       │     │MANUAL_           │    │DISEASE_            │
│OBSERVATIONS│     │IRRIGATION_LOGS   │    │SCANS               │
└────────────┘     └──────────────────┘    └────────────────────┘
    │                     │                        │
    └─────────────┬───────┴────────────────┬───────┘
                  │                        │
            ┌─────▼────────────────────────▼──────┐
            │     FIELD_OPERATIONS                │
            │ (Fertilizer, Pesticide, Irrigation)│
            └──────────────┬─────────────────────┘
                           │
              ┌────────────▼────────────┐
              │ YIELD_PREDICTIONS       │
              │ (Output from engine)    │
              └────────────┬────────────┘
                           │
                    ┌──────▼──────┐
                    │HARVEST_DATA │
                    │(Validation) │
                    └─────────────┘

Plus: BLOCKCHAIN_REFERENCES, ML_MODEL_LOGS
```

---

## Yield Prediction Flow

```
                    INPUT GATHERING
                    ════════════════

        ┌─────────────────────────────────────┐
        │ Collect data from all sources:      │
        │                                     │
        │ 1. sensor_readings (if available)  │
        │ 2. weather_data (API + manual)     │
        │ 3. field_observations (manual)     │
        │ 4. manual_irrigation_logs          │
        │ 5. field_operations                │
        │ 6. disease_scans                   │
        └────────────┬────────────────────────┘
                     │
        ┌────────────▼────────────────┐
        │ FEATURE ENGINEERING          │
        │                              │
        │ Calculate aggregate values:  │
        │ • avg_temperature            │
        │ • total_rainfall             │
        │ • soil_moisture_trend        │
        │ • fertilizer_applications    │
        │ • irrigation_volume          │
        │ • disease_pressure_index     │
        │ • data_quality_score         │
        └────────────┬─────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ MODEL SELECTION                      │
        │                                     │
        │ IF data_quality > 90% AND           │
        │    has_sensor_data AND             │
        │    has_weather_data:                │
        │   → Use FULL_PRECISION_MODEL       │
        │   → confidence_base = 0.95          │
        │                                     │
        │ ELSE IF data_quality > 70%:         │
        │   → Use HYBRID_MODEL               │
        │   → confidence_base = 0.80          │
        │                                     │
        │ ELSE:                               │
        │   → Use CONSERVATIVE_MODEL          │
        │   → confidence_base = 0.65          │
        └────────────┬─────────────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ APPLY MODEL                          │
        │                                     │
        │ yield_prediction =                  │
        │   base_yield *                      │
        │   weather_factor *                  │
        │   disease_factor *                  │
        │   management_factor *               │
        │   soil_factor                       │
        │                                     │
        │ confidence_final =                  │
        │   confidence_base *                 │
        │   data_quality_multiplier *         │
        │   historical_accuracy_factor        │
        └────────────┬─────────────────────────┘
                     │
                    OUTPUT
                    ══════════

        ┌────────────▼────────────────────────┐
        │ YIELD_PREDICTIONS (saved to DB)     │
        │                                     │
        │ • predicted_yield: 8,450 kg/ha      │
        │ • confidence_score: 0.92            │
        │ • yield_band: "high"                │
        │ • risk_factors: [                   │
        │     {"factor": "disease",           │
        │      "impact": -15%},               │
        │     {"factor": "low_rain",          │
        │      "impact": -5%}                 │
        │   ]                                 │
        │ • recommendations: [                │
        │     "Apply fungicide",              │
        │     "Increase irrigation"           │
        │   ]                                 │
        └────────────┬─────────────────────────┘
                     │
        ┌────────────▼────────────────────────┐
        │ PUSH TO FARMER'S PHONE              │
        │                                     │
        │ 🌾 Yield Forecast: 8,450 kg/ha      │
        │ 🎯 Confidence: High (92%)           │
        │ ⚠️  Alert: Early disease detected   │
        │    → Action: Spray fungicide ASAP   │
        │ 💧 Water: More irrigation needed    │
        │    → Target: +20mm this week        │
        └────────────────────────────────────┘
```

---

## Data Quality & Confidence Scoring

```
Data Completeness Calculation
═══════════════════════════════

    SENSOR DATA        MANUAL DATA       WEATHER DATA
    (30 days)          (30 days)         (30 days)
         │                  │                 │
    ┌────▼────┐        ┌────▼────┐     ┌────▼────┐
    │ 720/720 │        │  25/30  │     │ 30/30   │
    │ readings│        │entries  │     │ records │
    └────┬────┘        └────┬────┘     └────┬────┘
         │  100%            │  83%           │ 100%
         └────────────┬─────┴───────────────┘
                      │
         ┌────────────▼──────────────┐
         │ Overall Completeness      │
         │ = (100 + 83 + 100) / 3    │
         │ = 94%                     │
         │ = EXCELLENT COVERAGE      │
         └────────────┬───────────────┘
                      │
         ┌────────────▼──────────────┐
         │ Confidence Adjustment     │
         │                           │
         │ IF completeness > 90%:    │
         │   multiplier = 1.0        │
         │   (no reduction)          │
         │                           │
         │ IF completeness > 70%:    │
         │   multiplier = 0.85       │
         │   (slight reduction)      │
         │                           │
         │ IF completeness > 50%:    │
         │   multiplier = 0.70       │
         │   (moderate reduction)    │
         │                           │
         │ IF completeness < 50%:    │
         │   multiplier = 0.50       │
         │   (conservative)          │
         └────────────┬───────────────┘
                      │
         ┌────────────▼──────────────┐
         │ Final Confidence Score    │
         │                           │
         │ base_confidence * mult    │
         │ = 0.92 * 1.0              │
         │ = 0.92 (92%)              │
         │ = VERY HIGH               │
         └───────────────────────────┘
```

---

## Integration Points

```
FLUTTER APP
└── SUPABASE
    ├── PostgreSQL Database
    │   ├── Tables (15)
    │   ├── Views (aggregations)
    │   └── RLS Policies (security)
    │
    ├── Storage
    │   ├── /models (ML files)
    │   └── /field-photos (observations)
    │
    ├── Auth
    │   └── User authentication
    │
    └── Realtime
        └── Listen for yield prediction updates

FLUTTER SERVICES
├── WeatherService
├── FieldObservationService
├── IrrigationService
├── ScanProvider
├── FieldsProvider
└── AlertsProvider

EXTERNAL APIS
├── Weather Forecast API
│   └── (openweathermap, weatherapi, etc.)
│
└── Blockchain (Optional)
    ├── AgriAssetRegistry
    ├── AgriLoanMarket
    └── AgriYieldToken
```

---

## Deployment Architecture

```
                    ┌──────────────────┐
                    │  MOBILE APP      │
                    │  (iOS/Android)   │
                    └────────┬─────────┘
                             │
                    ┌────────▼────────┐
                    │ FLUTTER WEB     │
                    │ (Dashboard)     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼──┐    ┌─────▼────┐   ┌────▼──────┐
         │Supabase│   │ Weather  │   │Blockchain│
         │Backend │   │   API    │   │ Network  │
         │ Cloud  │   │          │   │(Ethereum)│
         └─────────┘   └──────────┘   └──────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────┐
                    │ ANALYTICS &     │
                    │ REPORTING       │
                    │ (BI Tools)      │
                    └─────────────────┘
```

---

## Success Metrics

```
✓ Migration Success
  • Firebase completely replaced
  • Zero data loss
  • All sensors still sending data
  • All farmers' local data synced

✓ Data Quality
  • 95%+ data completeness for farmers with sensors
  • 80%+ data completeness for manual-only farmers
  • <5% data corruption rate

✓ Yield Predictions
  • RMSE < 500 kg/ha (prediction error)
  • Confidence scores > 0.90 when data available
  • Successful risk alerts in 90% of cases

✓ User Experience
  • <5 seconds to submit observations
  • <2 seconds load time for predictions
  • 95%+ adoption rate among farmers

✓ System Performance
  • <100ms query response time
  • 99.9% uptime
  • 50ms websocket latency for real-time updates
```

---

This visual summary covers:
✅ System architecture
✅ All 3 data entry modes
✅ Database schema
✅ Prediction flow
✅ Quality scoring
✅ Integration points
✅ Deployment
✅ Success metrics

**Everything is documented and ready to implement!**
