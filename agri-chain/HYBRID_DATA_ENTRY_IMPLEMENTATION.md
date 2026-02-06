# Hybrid Data Entry Implementation Guide

## Overview

This guide shows how to implement the hybrid data entry (manual + automated) in your Flutter app using Supabase.

---

## Flutter App Architecture

### Data Entry Modes

```dart
enum DataEntryMode {
  manual,      // User enters all data manually
  automated,   // IoT sensors provide data
  hybrid       // Mix of both
}
```

---

## 1. Manual Weather Entry (for farmers without sensors)

### Dart Model

```dart
class ManualWeatherEntry {
  final String fieldId;
  final DateTime observationDate;
  final double temperature;
  final double humidity;
  final double rainfallMm;
  final String weatherCondition;
  final double windSpeedKmh;
  final String enteredBy;
  final String entryConfidence; // 'low', 'medium', 'high'
  final String notes;

  ManualWeatherEntry({
    required this.fieldId,
    required this.observationDate,
    required this.temperature,
    required this.humidity,
    required this.rainfallMm,
    required this.weatherCondition,
    required this.windSpeedKmh,
    required this.enteredBy,
    this.entryConfidence = 'medium',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'field_id': fieldId,
    'weather_date': observationDate.toIso8601String().split('T')[0],
    'temperature_celsius': temperature,
    'humidity_percent': humidity,
    'rainfall_mm': rainfallMm,
    'weather_condition': weatherCondition,
    'wind_speed_kmh': windSpeedKmh,
    'data_source': 'manual_observation',
    'entered_by': enteredBy,
    'entry_confidence': entryConfidence,
    'entry_notes': notes,
  };
}
```

### Supabase Service

```dart
class WeatherService {
  final SupabaseClient supabase;

  WeatherService(this.supabase);

  /// Add manual weather observation
  Future<void> addManualWeatherObservation(
    ManualWeatherEntry entry,
  ) async {
    try {
      await supabase
          .from('weather_data')
          .insert(entry.toJson());
      print('Weather observation saved');
    } catch (e) {
      print('Error saving weather: $e');
      rethrow;
    }
  }

  /// Get latest weather for a field (manual + API)
  Future<List<Map<String, dynamic>>> getFieldWeather(
    String fieldId, {
    required int daysBack,
  }) async {
    try {
      final response = await supabase
          .from('weather_data')
          .select()
          .eq('field_id', fieldId)
          .gte('weather_date',
              DateTime.now().subtract(Duration(days: daysBack)).toIso8601String())
          .order('weather_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching weather: $e');
      return [];
    }
  }
}
```

---

## 2. Manual Field Observations

### Dart Model

```dart
class FieldObservation {
  final String fieldId;
  final String plantingId;
  final DateTime observationDate;
  final double? plantHeightCm;
  final String? leafColor;
  final int? leafHealthPercent;
  final String? pestName;
  final int? pestCountPer10Plants;
  final bool diseaseObserved;
  final String? diseaseName;
  final String? diseaseSeverity;
  final double? affectedPlantsPercent;
  final String? photoUrl;
  final String confidenceLevel;
  final String notes;

  FieldObservation({
    required this.fieldId,
    required this.plantingId,
    required this.observationDate,
    this.plantHeightCm,
    this.leafColor,
    this.leafHealthPercent,
    this.pestName,
    this.pestCountPer10Plants,
    this.diseaseObserved = false,
    this.diseaseName,
    this.diseaseSeverity,
    this.affectedPlantsPercent,
    this.photoUrl,
    this.confidenceLevel = 'medium',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'field_id': fieldId,
    'planting_id': plantingId,
    'observation_date': observationDate.toIso8601String().split('T')[0],
    'plant_height_cm': plantHeightCm,
    'leaf_color': leafColor,
    'leaf_health_percent': leafHealthPercent,
    'pest_name': pestName,
    'pest_count_per_10_plants': pestCountPer10Plants,
    'disease_observed': diseaseObserved,
    'disease_name': diseaseName,
    'disease_severity': diseaseSeverity,
    'affected_plants_percent': affectedPlantsPercent,
    'photo_url': photoUrl,
    'confidence_level': confidenceLevel,
    'notes': notes,
  };
}
```

### Service

```dart
class FieldObservationService {
  final SupabaseClient supabase;

  FieldObservationService(this.supabase);

  Future<void> recordObservation(FieldObservation observation) async {
    try {
      await supabase
          .from('field_observations')
          .insert(observation.toJson());
      print('Observation recorded');
    } catch (e) {
      print('Error recording observation: $e');
      rethrow;
    }
  }

  Future<List<FieldObservation>> getFieldObservations(
    String fieldId,
    String plantingId,
  ) async {
    try {
      final response = await supabase
          .from('field_observations')
          .select()
          .eq('field_id', fieldId)
          .eq('planting_id', plantingId)
          .order('observation_date', ascending: false);

      return (response as List)
          .map((o) => _mapToFieldObservation(o))
          .toList();
    } catch (e) {
      print('Error fetching observations: $e');
      return [];
    }
  }

  FieldObservation _mapToFieldObservation(Map<String, dynamic> json) {
    return FieldObservation(
      fieldId: json['field_id'],
      plantingId: json['planting_id'],
      observationDate: DateTime.parse(json['observation_date']),
      plantHeightCm: json['plant_height_cm']?.toDouble(),
      leafColor: json['leaf_color'],
      leafHealthPercent: json['leaf_health_percent'],
      pestName: json['pest_name'],
      pestCountPer10Plants: json['pest_count_per_10_plants'],
      diseaseObserved: json['disease_observed'] ?? false,
      diseaseName: json['disease_name'],
      diseaseSeverity: json['disease_severity'],
      affectedPlantsPercent: json['affected_plants_percent']?.toDouble(),
      photoUrl: json['photo_url'],
      confidenceLevel: json['confidence_level'] ?? 'medium',
      notes: json['notes'] ?? '',
    );
  }
}
```

---

## 3. Manual Irrigation Logging

### Dart Model

```dart
class IrrigationLog {
  final String fieldId;
  final String plantingId;
  final DateTime irrigationDate;
  final TimeOfDay? startTime;
  final double durationHours;
  final String method; // 'drip', 'flood', 'sprinkler', 'furrow'
  final String waterSource; // 'well', 'borehole', 'canal'
  final double? volumeLiters;
  final double? estimatedRainfallEquivalentMm;
  final String soilMoistureBefore; // 'dry', 'moist', 'wet'
  final String soilMoistureAfter;
  final bool runoffObserved;
  final String notes;

  IrrigationLog({
    required this.fieldId,
    required this.plantingId,
    required this.irrigationDate,
    this.startTime,
    required this.durationHours,
    required this.method,
    required this.waterSource,
    this.volumeLiters,
    this.estimatedRainfallEquivalentMm,
    required this.soilMoistureBefore,
    required this.soilMoistureAfter,
    this.runoffObserved = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'field_id': fieldId,
    'planting_id': plantingId,
    'irrigation_date': irrigationDate.toIso8601String().split('T')[0],
    'irrigation_start_time': startTime?.format(context: null), // adjust context
    'irrigation_duration_hours': durationHours,
    'irrigation_method': method,
    'water_source': waterSource,
    'volume_liters': volumeLiters,
    'estimated_rainfall_equivalent_mm': estimatedRainfallEquivalentMm,
    'soil_moisture_before': soilMoistureBefore,
    'soil_moisture_after': soilMoistureAfter,
    'runoff_observed': runoffObserved,
    'notes': notes,
  };
}
```

### Service

```dart
class IrrigationService {
  final SupabaseClient supabase;

  IrrigationService(this.supabase);

  Future<void> logIrrigation(IrrigationLog log) async {
    try {
      await supabase
          .from('manual_irrigation_logs')
          .insert(log.toJson());
      print('Irrigation logged');
    } catch (e) {
      print('Error logging irrigation: $e');
      rethrow;
    }
  }

  Future<double> getTotalIrrigationThisMonth(
    String fieldId,
  ) async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth =
          DateTime(now.year, now.month, 1);

      final response = await supabase
          .from('manual_irrigation_logs')
          .select('estimated_rainfall_equivalent_mm')
          .eq('field_id', fieldId)
          .gte('irrigation_date', firstDayOfMonth.toIso8601String());

      double total = 0;
      for (var record in response) {
        total += (record['estimated_rainfall_equivalent_mm'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      print('Error calculating irrigation: $e');
      return 0;
    }
  }
}
```

---

## 4. UI: Data Entry Form Example

### Weather Entry Screen

```dart
class ManualWeatherEntryScreen extends StatefulWidget {
  final String fieldId;

  const ManualWeatherEntryScreen({required this.fieldId});

  @override
  State<ManualWeatherEntryScreen> createState() => _ManualWeatherEntryScreenState();
}

class _ManualWeatherEntryScreenState extends State<ManualWeatherEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weatherService = WeatherService(Supabase.instance.client);

  late TextEditingController _temperatureController;
  late TextEditingController _humidityController;
  late TextEditingController _rainfallController;
  late TextEditingController _windSpeedController;

  String _selectedWeatherCondition = 'sunny';
  String _selectedConfidence = 'medium';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _humidityController = TextEditingController();
    _rainfallController = TextEditingController();
    _windSpeedController = TextEditingController();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _rainfallController.dispose();
    _windSpeedController.dispose();
    super.dispose();
  }

  Future<void> _submitWeatherEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final entry = ManualWeatherEntry(
      fieldId: widget.fieldId,
      observationDate: _selectedDate,
      temperature: double.parse(_temperatureController.text),
      humidity: double.parse(_humidityController.text),
      rainfallMm: double.parse(_rainfallController.text),
      weatherCondition: _selectedWeatherCondition,
      windSpeedKmh: double.parse(_windSpeedController.text),
      enteredBy: Supabase.instance.client.auth.currentUser!.id,
      entryConfidence: _selectedConfidence,
    );

    try {
      await _weatherService.addManualWeatherObservation(entry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weather observation saved!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Weather')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Date picker
              ListTile(
                title: const Text('Observation Date'),
                subtitle: Text(_selectedDate.toIso8601String().split('T')[0]),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Temperature
              TextFormField(
                controller: _temperatureController,
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C)',
                  prefixIcon: Icon(Icons.thermostat),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Humidity
              TextFormField(
                controller: _humidityController,
                decoration: const InputDecoration(
                  labelText: 'Humidity (%)',
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Rainfall
              TextFormField(
                controller: _rainfallController,
                decoration: const InputDecoration(
                  labelText: 'Rainfall (mm)',
                  prefixIcon: Icon(Icons.cloud_download),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Weather condition dropdown
              DropdownButtonFormField<String>(
                value: _selectedWeatherCondition,
                decoration: const InputDecoration(
                  labelText: 'Weather Condition',
                  prefixIcon: Icon(Icons.cloud),
                ),
                items: ['sunny', 'cloudy', 'rainy', 'stormy']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWeatherCondition = v ?? ''),
              ),
              const SizedBox(height: 12),

              // Wind speed
              TextFormField(
                controller: _windSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Wind Speed (km/h)',
                  prefixIcon: Icon(Icons.air),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Confidence level
              DropdownButtonFormField<String>(
                value: _selectedConfidence,
                decoration: const InputDecoration(
                  labelText: 'Confidence Level',
                  prefixIcon: Icon(Icons.check_circle),
                ),
                items: ['low', 'medium', 'high']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedConfidence = v ?? ''),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submitWeatherEntry,
                child: const Text('Save Weather Observation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 5. Data Completeness Check UI

### Show user what data is missing

```dart
class DataCompletenessWidget extends StatelessWidget {
  final String fieldId;
  final SupabaseClient supabase;

  const DataCompletenessWidget({
    required this.fieldId,
    required this.supabase,
  });

  Future<Map<String, dynamic>> getDataCompleteness() async {
    try {
      final response = await supabase
          .rpc('get_field_data_completeness', params: {'field_id': fieldId});
      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getDataCompleteness(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Text('Error loading data completeness');
        }

        final data = snapshot.data!;
        final completenessPercent = data['completeness_percent'] as int? ?? 0;
        final sensorRecords = data['sensor_records'] as int? ?? 0;
        final manualRecords = data['manual_records'] as int? ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data Completeness',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completenessPercent / 100,
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Sensor Data'),
                        Text('$sensorRecords records',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Manual Entry'),
                        Text('$manualRecords records',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Overall'),
                        Text('$completenessPercent%',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (completenessPercent < 70)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ Please add more data for accurate yield predictions',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## 6. Supabase Functions: PostgreSQL Triggers

### Auto-calculate data completeness

```sql
CREATE OR REPLACE FUNCTION update_weather_data_completeness()
RETURNS TRIGGER AS $$
BEGIN
  -- Count non-null fields
  NEW.data_completeness_percent := 
    (CASE WHEN NEW.temperature_celsius IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN NEW.humidity_percent IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN NEW.rainfall_mm IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN NEW.wind_speed_kmh IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN NEW.solar_radiation_w_per_m2 IS NOT NULL THEN 1 ELSE 0 END) * 20;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_weather_completeness
BEFORE INSERT OR UPDATE ON weather_data
FOR EACH ROW
EXECUTE FUNCTION update_weather_data_completeness();
```

---

## 7. Data Aggregation for Yield Engine

### Function to get all features for prediction

```sql
CREATE OR REPLACE FUNCTION get_yield_prediction_features(
  p_field_id UUID,
  p_planting_id UUID,
  p_days_back INT DEFAULT 30
)
RETURNS TABLE(
  field_id UUID,
  planting_id UUID,
  avg_temperature DECIMAL,
  avg_humidity DECIMAL,
  avg_soil_moisture DECIMAL,
  total_rainfall DECIMAL,
  fertilizer_applications INT,
  irrigation_applications INT,
  pesticide_applications INT,
  disease_risk_score DECIMAL,
  data_quality_score INT,
  sensor_data_days INT,
  manual_observation_days INT
) AS $$
BEGIN
  RETURN QUERY
  WITH field_data AS (
    SELECT 
      f.id,
      p.id as planting_id
    FROM fields f
    LEFT JOIN plantings p ON f.id = p.field_id
    WHERE f.id = p_field_id AND p.id = p_planting_id
  ),
  weather_stats AS (
    SELECT 
      AVG(temperature_celsius) as avg_temp,
      AVG(humidity_percent) as avg_humidity,
      SUM(rainfall_mm) as total_rainfall
    FROM weather_data
    WHERE field_id = p_field_id
      AND weather_date >= CURRENT_DATE - INTERVAL '1 day' * p_days_back
      AND is_forecast = FALSE
  ),
  sensor_stats AS (
    SELECT 
      s.sensor_type,
      AVG(sr.reading_value) as avg_reading
    FROM sensor_readings sr
    JOIN sensors s ON sr.sensor_id = s.id
    WHERE s.field_id = p_field_id
      AND sr.created_at >= NOW() - INTERVAL '1 day' * p_days_back
    GROUP BY s.sensor_type
  ),
  operations_count AS (
    SELECT 
      COUNT(CASE WHEN operation_type = 'fertilizer' THEN 1 END)::INT as fertilizer_count,
      COUNT(CASE WHEN operation_type = 'irrigation' THEN 1 END)::INT as irrigation_count,
      COUNT(CASE WHEN operation_type = 'pesticide' THEN 1 END)::INT as pesticide_count
    FROM field_operations
    WHERE field_id = p_field_id
      AND planting_id = p_planting_id
  ),
  disease_stats AS (
    SELECT 
      COALESCE(SUM(confidence_score), 0)::DECIMAL as disease_risk
    FROM disease_scans
    WHERE field_id = p_field_id
      AND planting_id = p_planting_id
  ),
  observation_days AS (
    SELECT 
      COUNT(DISTINCT DATE(created_at))::INT as sensor_days,
      COUNT(DISTINCT DATE(observation_date))::INT as manual_days
    FROM (
      SELECT created_at FROM sensor_readings WHERE sensor_id IN (SELECT id FROM sensors WHERE field_id = p_field_id)
      UNION ALL
      SELECT observation_date::TIMESTAMP FROM field_observations WHERE field_id = p_field_id
    ) as combined_data
    WHERE created_at >= NOW() - INTERVAL '1 day' * p_days_back
      OR observation_date >= NOW() - INTERVAL '1 day' * p_days_back
  )
  SELECT 
    fd.id,
    fd.planting_id,
    ws.avg_temp,
    ws.avg_humidity,
    (SELECT avg_reading FROM sensor_stats WHERE sensor_type = 'soil_moisture'),
    ws.total_rainfall,
    oc.fertilizer_count,
    oc.irrigation_count,
    oc.pesticide_count,
    ds.disease_risk,
    ROUND(100.0 * (od.sensor_days + od.manual_days) / (p_days_back * 2))::INT,
    od.sensor_days,
    od.manual_days
  FROM field_data fd
  CROSS JOIN weather_stats ws
  CROSS JOIN operations_count oc
  CROSS JOIN disease_stats ds
  CROSS JOIN observation_days od;
END;
$$ LANGUAGE plpgsql;
```

---

## Summary: Implementation Checklist

- [ ] Create `field_observations` table
- [ ] Create `manual_irrigation_logs` table
- [ ] Update `sensor_readings` with `data_source` column
- [ ] Update `weather_data` with manual entry fields
- [ ] Create Dart models for manual entries
- [ ] Create Supabase services for data operations
- [ ] Build UI forms for manual entry
- [ ] Create data completeness widget
- [ ] Set up PostgreSQL triggers for auto-calculation
- [ ] Create aggregation function for yield engine
- [ ] Test hybrid data flow (manual + sensor)
- [ ] Deploy to production

---

**Result**: Your app now supports:
✅ Fully automated (sensors only)
✅ Fully manual (farmers enter everything)
✅ Hybrid (best of both)
✅ Yield predictions adapt based on data availability
