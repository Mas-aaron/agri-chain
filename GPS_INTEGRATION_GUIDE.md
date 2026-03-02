# 🗺️ GPS Integration Guide - Agri Chain Rover

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Hardware Setup](#hardware-setup)
4. [Software Implementation](#software-implementation)
5. [API Endpoints](#api-endpoints)
6. [Flutter Integration](#flutter-integration)
7. [Usage Guide](#usage-guide)
8. [Troubleshooting](#troubleshooting)
9. [Future Enhancements](#future-enhancements)

---

## Overview

This document describes the complete GPS integration implemented for the Agri Chain Rover system. The system enables real-time positioning, satellite tracking, and navigation data through a dedicated Flutter screen with REST API backend.

### Features
- ✅ Real-time GPS positioning and tracking
- ✅ Live satellite visibility monitoring
- ✅ Signal quality assessment (HDOP)
- ✅ Speed and course display
- ✅ Altitude tracking
- ✅ Data freshness monitoring
- ✅ Auto-polling every 2 seconds
- ✅ Visual status indicators
- ✅ WiFi & Bluetooth connectivity
- ✅ Comprehensive debug logging

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NEO-6M GPS Module                         │
│                    (u-blox RTK-capable)                      │
│                                                              │
│  - Antenna: Receives satellite signals                       │
│  - UART Serial output: NMEA-0183 @ 9600 baud               │
└──────────────────┬──────────────────────────────────────────┘
                   │ GPIO 16 (RX), GPIO 17 (TX)
                   │
┌──────────────────▼──────────────────────────────────────────┐
│                   ESP32-WROOM                                │
│                     (Main Controller)                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ TinyGPS++ Library (NMEA Parsing)                     │   │
│  │ - Decodes satellite signals                          │   │
│  │ - Extracts position, speed, course, altitude        │   │
│  └────────────────┬─────────────────────────────────────┘   │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────────────┐   │
│  │ gpsData Struct (In-Memory Storage)                   │   │
│  │ - latitude, longitude, altitude                      │   │
│  │ - speed (m/s), course (degrees)                      │   │
│  │ - satellites, hdop, timestamp                        │   │
│  │ - isValid, requestCount, dataUpdates                 │   │
│  └────────────────┬─────────────────────────────────────┘   │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────────────┐   │
│  │ WebServer (HTTP REST API)                            │   │
│  │ GET /api/gps/data → JSON response                    │   │
│  │ GET /gps → Shortcut endpoint                         │   │
│  └────────────────┬─────────────────────────────────────┘   │
│                   │ WiFi (192.168.4.1:80)                    │
└───────────────────┼────────────────────────────────────────┘
                    │
┌───────────────────▼────────────────────────────────────────┐
│              Flutter Mobile App (Rover App)                  │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ RoverProvider (State Management)                   │   │
│  │ - fetchGPSData(): HTTP GET /api/gps/data           │   │
│  │ - startGPSPolling(): Auto-poll every 2 seconds     │   │
│  │ - gpsData: GPSData model (JsonSerializable)        │   │
│  └────────────────┬───────────────────────────────────┘   │
│                   │                                        │
│  ┌────────────────▼───────────────────────────────────┐   │
│  │ GPSDataScreen (UI Widget)                         │   │
│  │ - GPS Status Card (signal valid/invalid)          │   │
│  │ - Location Card (lat, lon, alt, coordinates)      │   │
│  │ - Movement Card (speed, course, heading)          │   │
│  │ - Satellite Card (sat count, HDOP, quality)       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Data Flow

```
updateGPS() loop
    ↓
Read UART Serial2
    ↓
TinyGPS++.encode(c)
    ↓
gps.location.isValid()
    ↓
├─ TRUE: Update gpsData struct + logging
│        gpsData.dataUpdates++
│        Serial: "✅ GPS FIX #1"
│
└─ FALSE: Still searching
         gpsData.satellites = count
         Serial: "🔄 Searching..."

Parallel:
  RoverProvider.fetchGPSData()
    ↓
  HTTP GET /api/gps/data
    ↓
  handleGPS() handler
    ↓
  gpsData.requestCount++
    ↓
  Serial: "📡 GPS API Request #1"
    ↓
  JSON response to Flutter
    ↓
  GPSDataScreen renders
```

---

## Hardware Setup

### Components Required

| Component | Model | Purpose | Qty |
|-----------|-------|---------|-----|
| GPS Module | NEO-6M (u-blox) | Satellite positioning | 1 |
| Antenna | 28dBi ceramic patch | Receives satellite signals | 1 |
| Microcontroller | ESP32-WROOM-32D | Main processor | 1 |
| USB-to-UART | CP2102 | Programming & debugging | 1 |
| Capacitor | 0.1µF ceramic | Power filtering | 1 |
| Wires | 22 AWG | Connections | As needed |

### Wiring Diagram

```
NEO-6M GPS Module          ESP32 Board
─────────────────          ───────────
VCC (3.3V/5V)    ────→    3V3 (Pin 3V3)
                           ┌─────────────┐
                           │    ESP32    │
GND              ────→    GND (Pin 38)  │
                           │             │
TX (Serial out)  ────→    GPIO 16 (RX) │  Serial2
RX (Serial in)   ────→    GPIO 17 (TX) │
                           │             │
                           └─────────────┘

Antenna          ────→    U.FL connector on NEO-6M
```

### Pin Configuration

```cpp
#define GPS_RX 16      // Receives data from NEO-6M TX
#define GPS_TX 17      // Sends data to NEO-6M RX
#define GPS_BAUD 9600  // Standard NEO-6M baud rate

HardwareSerial gpsSerial(2);  // Serial2 on ESP32
```

### Power Considerations

- **VCC Supply**: 3.3V (recommended) or 5V via voltage regulator
- **Capacitor**: 0.1µF between VCC and GND (stability)
- **Current Draw**: ~50mA typical
- **Antenna**: Must be outdoors or near window for satellite visibility

---

## Software Implementation

### ESP32 Code (rover.ino)

#### GPS Module Initialization

```cpp
void initGPS() {
  Serial.print(F("Initializing GPS module..."));
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println(F(" ✓"));
  Serial.println(F("  └─ Baud Rate: 9600"));
  Serial.println(F("  └─ Listening for satellite data..."));
}
```

Called during `setup()` after pin initialization.

#### GPS Data Structure

```cpp
struct {
  double latitude = 0.0;              // Degrees (-180 to +180)
  double longitude = 0.0;             // Degrees (-90 to +90)
  double altitude = 0.0;              // Meters above sea level
  double speed = 0.0;                 // Meters per second
  double course = 0.0;                // Degrees (0-360)
  int satellites = 0;                 // Number visible
  double hdop = 99.99;                // Horizontal dilution of precision
  unsigned long timestamp = 0;        // GPS time
  bool isValid = false;               // Has valid fix?
  unsigned long lastReceivedTime = 0; // When last fix received
  unsigned long lastRequestTime = 0;  // When last API request
  int requestCount = 0;               // Total API requests
  int dataUpdates = 0;                // Total position updates
} gpsData;
```

#### GPS Data Update Loop

```cpp
void updateGPS() {
  // Read available GPS data
  while (gpsSerial.available() > 0) {
    char c = gpsSerial.read();
    if (gps.encode(c)) {
      // Complete NMEA sentence decoded
      if (gps.location.isValid()) {
        // Valid fix acquired
        gpsData.latitude = gps.location.lat();
        gpsData.longitude = gps.location.lng();
        gpsData.altitude = gps.altitude.meters();
        gpsData.speed = gps.speed.mps();        // m/s
        gpsData.course = gps.course.deg();
        gpsData.satellites = gps.satellites.value();
        gpsData.hdop = gps.hdop.hdop();
        gpsData.timestamp = gps.date.value() * 1000000 + gps.time.value();
        gpsData.isValid = true;
        gpsData.lastReceivedTime = millis();
        gpsData.dataUpdates++;
        
        // Log every 5 seconds
        static unsigned long lastLog = 0;
        if (millis() - lastLog > 5000) {
          Serial.print(F("✅ GPS FIX #"));
          Serial.print(gpsData.dataUpdates);
          Serial.print(F(": Lat="));
          Serial.print(gpsData.latitude, 6);
          Serial.print(F(" Lon="));
          Serial.print(gpsData.longitude, 6);
          Serial.print(F(" Sats="));
          Serial.print(gpsData.satellites);
          Serial.print(F(" HDOP="));
          Serial.println(gpsData.hdop, 2);
          lastLog = millis();
        }
      } else {
        // Searching for satellites
        gpsData.isValid = false;
        if (gps.satellites.value() > 0) {
          gpsData.satellites = gps.satellites.value();
          
          // Log search progress every 10 seconds
          static unsigned long lastSearchLog = 0;
          if (millis() - lastSearchLog > 10000) {
            Serial.print(F("🔄 Searching for GPS fix... Satellites visible: "));
            Serial.println(gpsData.satellites);
            lastSearchLog = millis();
          }
        }
      }
    }
  }
}
```

Called in main `loop()` every 10ms.

#### Libraries Required

```cpp
#include <TinyGPS++.h>  // Download from: https://github.com/mikalhart/TinyGPS

// In Arduino IDE:
// Sketch → Include Library → Manage Libraries
// Search "TinyGPS++" → Install by Mikal Hart
```

### Flutter Code

#### GPS Data Model

```dart
class GPSData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;           // m/s
  final double course;          // degrees
  final int satellites;
  final double hdop;            // horizontal dilution of precision
  final DateTime timestamp;
  final bool isValid;

  factory GPSData.fromJson(Map<String, dynamic> json) {
    return GPSData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      satellites: json['satellites'] as int? ?? 0,
      hdop: (json['hdop'] as num?)?.toDouble() ?? 99.99,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isValid: json['is_valid'] as bool? ?? false,
    );
  }

  // Helper getters
  String get coordinatesString => '$latitude, $longitude';
  String get speedKmh => '${(speed * 3.6).toStringAsFixed(2)} km/h';
  String get courseString {
    if (course < 0 || course > 360) return 'N/A';
    if (course < 22.5 || course >= 337.5) return 'N';
    if (course < 67.5) return 'NE';
    if (course < 112.5) return 'E';
    if (course < 157.5) return 'SE';
    if (course < 202.5) return 'S';
    if (course < 247.5) return 'SW';
    if (course < 292.5) return 'W';
    return 'NW';
  }
}
```

#### RoverProvider Updates

```dart
class RoverProvider extends ChangeNotifier {
  GPSData _gpsData = GPSData.invalid;
  Timer? _gpsTimer;

  GPSData get gpsData => _gpsData;

  // Fetch GPS data from rover
  Future<void> fetchGPSData() async {
    if (!_isConnected) return;

    if (_connectionType == ConnectionType.wifi) {
      try {
        final response = await http
            .get(Uri.parse('http://$_wifiIP/api/gps/data'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _gpsData = GPSData.fromJson(data);
          notifyListeners();
        }
      } catch (_) {
        // GPS data fetch failed, keep previous data
      }
    }
  }

  // Auto-poll GPS data every 2 seconds
  void startGPSPolling({Duration interval = const Duration(seconds: 2)}) {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(interval, (_) {
      fetchGPSData();
    });
  }

  // Stop polling
  void stopGPSPolling() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }
}
```

---

## API Endpoints

### Base URL
```
http://192.168.4.1/api/
```

### GET /api/gps/data

**Description**: Retrieve current GPS position and satellite data

**Method**: `GET`

**Response Code**: `200 OK`

**Response Format**: `application/json`

**Response Body**:

```json
{
  "latitude": 40.712776,
  "longitude": -74.005974,
  "altitude": 10.5,
  "speed": 0.0,
  "course": 45.5,
  "satellites": 12,
  "hdop": 1.2,
  "timestamp": "1708435200000000",
  "is_valid": true,
  "signal_quality": "Good",
  "last_received_ms_ago": 2341,
  "total_requests": 8,
  "total_updates": 25,
  "last_update": 125432100
}
```

**Response Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `latitude` | double | GPS latitude (-90 to +90 degrees) |
| `longitude` | double | GPS longitude (-180 to +180 degrees) |
| `altitude` | double | Height above sea level in meters |
| `speed` | double | Current speed in meters per second |
| `course` | double | Heading direction in degrees (0-360) |
| `satellites` | int | Number of visible satellites |
| `hdop` | double | Horizontal Dilution of Precision (lower = better) |
| `timestamp` | string | GPS time when fix was acquired |
| `is_valid` | boolean | Whether position fix is valid |
| `signal_quality` | string | Quality assessment: "Excellent", "Good", "Fair", "Poor" |
| `last_received_ms_ago` | int | Milliseconds since last GPS update |
| `total_requests` | int | Total API requests served |
| `total_updates` | int | Total GPS position updates received |
| `last_update` | int | System uptime in milliseconds |

**Quality Levels**:
- **Excellent**: HDOP < 1.0
- **Good**: HDOP 1.0-2.0
- **Fair**: HDOP 2.0-5.0
- **Poor**: HDOP > 5.0

**Example cURL Request**:

```bash
curl http://192.168.4.1/api/gps/data
```

**Example cURL Response**:

```json
{
  "latitude": 40.712776,
  "longitude": -74.005974,
  "altitude": 10.5,
  "speed": 2.5,
  "course": 120.5,
  "satellites": 12,
  "hdop": 1.2,
  "timestamp": "1708435200000000",
  "is_valid": true,
  "signal_quality": "Good",
  "last_received_ms_ago": 1200,
  "total_requests": 42,
  "total_updates": 156,
  "last_update": 234532100
}
```

### GET /gps

**Shortcut endpoint** - Same as `/api/gps/data`

---

## Flutter Integration

### GPS Screen File
**Location**: `lib/rover/screens/gps_screen.dart`

### Features

#### 1. GPS Status Card
Shows signal strength and validity:
- 🟢 Green badge: Valid GPS fix acquired
- 🔴 Red badge: Searching for satellites
- Animated icons with status messages

#### 2. Location Card
Displays positional information:
- Latitude with 8 decimal precision
- Longitude with 8 decimal precision
- Altitude in meters
- Full coordinates string

#### 3. Movement Card
Shows heading and motion data:
- Speed converted to km/h
- Course heading in degrees
- Cardinal direction (N, NE, E, SE, S, SW, W, NW)
- Last update timestamp (HH:MM:SS)

#### 4. Satellite Card
Provides signal quality metrics:
- Number of visible satellites (0-32)
- HDOP value (0.0 - 99.99)
- Signal quality assessment
- Quality color indicators

#### 5. No GPS Card
Gracefully handles unavailable GPS:
- Large icon indicating no signal
- Helpful troubleshooting tips
- Reasons GPS might be unavailable

### Opening GPS Screen

From main rover control screen:
```dart
IconButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GPSDataScreen()),
  ),
  icon: const Icon(Icons.fullscreen, color: Colors.orange),
  tooltip: 'View Full GPS Data',
)
```

### Data Updates

GPS data updates automatically via polling:
```dart
// Started when connected
provider.startGPSPolling();  // Every 2 seconds

// Stopped when disconnected
provider.stopGPSPolling();

// Manual refresh with button
await provider.fetchGPSData();
```

---

## Usage Guide

### Basic Operation

#### 1. Power Up Rover
```
• Connect battery to ESP32
• Wait for Serial initialization
• Should see: "✅ SYSTEM READY"
```

#### 2. Position Antenna Outdoors
```
• Place GPS antenna in open sky view
• Buildings and trees block signals
• Wait 30-60 seconds for initial fix
• Serial shows: "✅ GPS FIX #1: Lat=..."
```

#### 3. Connect Mobile App
```
• Open Rover App on Flutter device
• Connect via WiFi to "ESP32_Rover"
• See GPS widget on main screen
• 🟢 Green badge = GPS locked
```

#### 4. View GPS Data
```
• Tap fullscreen expand icon next to GPS widget
• Opens GPSDataScreen with detailed data
• Data refreshes every 2 seconds automatically
• Tap "Refresh GPS Data" button for immediate update
```

### Interpreting GPS Data

#### Latitude & Longitude
- Positive latitude = North of equator
- Negative latitude = South of equator  
- Positive longitude = East of prime meridian
- Negative longitude = West of prime meridian

**Example**: 40.712776°N, -74.005974°W (New York City)

#### Speed
- Displayed in km/h (converted from m/s)
- 0.0 when stationary
- Max typically ~5 km/h for rover

#### Course (Heading)
- Degrees from 0-360°
- 0° = North
- 90° = East
- 180° = South
- 270° = West

#### Satellites
- Minimum 4 needed for valid 3D fix
- More satellites = more accurate
- Typical range: 6-12 satellites

#### HDOP (Horizontal Dilution of Precision)
- Measures satellite geometry quality
- Lower = better accuracy
- 1.0 = Excellent (±5m typical)
- 2.0 = Good (±10m typical)
- 5.0 = Fair (±30m typical)
- >5.0 = Poor (unreliable)

### Serial Monitor Debugging

Connect via USB and open Serial Monitor at **115200 baud**:

**Initialization**:
```
Initializing GPS module...✓
  └─ Baud Rate: 9600
  └─ Listening for satellite data...
```

**Searching**:
```
🔄 Searching for GPS fix... Satellites visible: 5
🔄 Searching for GPS fix... Satellites visible: 10
```

**Got Fix**:
```
✅ GPS FIX #1: Lat=40.712776 Lon=-74.005974 Sats=12 HDOP=1.20
✅ GPS FIX #2: Lat=40.712783 Lon=-74.005981 Sats=12 HDOP=1.19
```

**API Requests**:
```
📡 GPS API Request #1 → Lat: 40.712776, Lon: -74.005974, Sats: 12, Valid: YES
📡 GPS API Request #2 → Lat: 40.712783, Lon: -74.005981, Sats: 12, Valid: YES
```

---

## Troubleshooting

### GPS Not Acquiring Fix

**Symptoms**:
- 🔴 Red "No Fix" badge in app
- Serial shows: "🔄 Searching..." indefinitely
- Satellites = 0

**Possible Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Indoors/blocked | Move antenna outdoors, away from buildings |
| Antenna disconnected | Check U.FL connector is fully seated |
| Antenna damaged | Try different antenna or test with known-good |
| GPS module failure | Test GPS module in isolation with USB cable |
| Wrong baud rate | Verify 9600 in `GPS_BAUD` definition |
| Wiring issue | Check GPIO 16/17 connections |

**Diagnostic Steps**:
1. Check Serial Monitor for "Searching..." messages
2. Wait 2-3 minutes in clear sky
3. Check antenna connector is tight
4. Verify GPS module has power (LED should blink)
5. Test with different location

### GPS Loses Lock Frequently

**Symptoms**:
- Position jumps around
- Satellites varies 2-10
- HDOP > 5.0
- "Fair" or "Poor" signal quality

**Causes**:
- Poor antenna placement
- Too close to metal
- Weather/atmospheric conditions

**Solutions**:
- Move antenna higher and more open
- Keep away from metal structures
- Move to different location for testing
- Wait for better atmospheric conditions

### API Returns Zero Values

**Symptoms**:
- Latitude/Longitude = 0.0
- `is_valid` = false
- All values = 0

**Cause**: GPS hasn't acquired fix yet

**Solution**:
- Wait 30-60 seconds
- Ensure antenna is outdoors
- Check Serial Monitor for "Searching..." status
- Verify antenna connection

### App Not Receiving Data

**Symptoms**:
- GPS screen shows gray "No Data"
- Serial shows GPS FIX but app shows 0.0

**Causes**:
- WiFi connection lost
- Wrong rover IP address
- Firewall blocking port 80

**Solutions**:
1. Verify WiFi connection to "ESP32_Rover"
2. Ping rover: `ping 192.168.4.1`
3. Test endpoint in browser: `http://192.168.4.1/api/gps/data`
4. Check Firebase/network diagnostics in app

### High HDOP / Poor Signal

**Symptoms**:
- HDOP > 5.0
- Accuracy ±50m or worse
- "Poor" signal quality badge

**Causes**:
- Satellites in poor geometry
- Blocked/limited sky view
- Urban canyon effect

**Solutions**:
- Move to open area
- Increase antenna height
- Wait for satellite geometry to improve
- Consider RTK correction for better accuracy

---

## Performance Metrics

### Typical Performance

| Metric | Value |
|--------|-------|
| **Time to First Fix (TTFF)** | 30-120 seconds (cold start) |
| **Position Accuracy** | ±5-15 meters (good conditions) |
| **Speed Accuracy** | ±0.1 m/s |
| **HDOP Range** | 0.8 - 5.0 (typical) |
| **Satellites** | 8-12 (urban), 12+ (open sky) |
| **Update Rate** | 1 Hz (1 position/second) |
| **API Response Time** | <50ms |
| **Polling Interval** | 2 seconds |

### Power Consumption

| Component | Current | Notes |
|-----------|---------|-------|
| GPS Module | ~50 mA | Typical in use |
| ESP32 | ~50 mA | Core + WiFi |
| **Total** | **100 mA** | Typical system |

---

## Future Enhancements

### Planned Features

- [ ] **Map Visualization**: Display current location on map widget
- [ ] **Waypoint Navigation**: Set and navigate to target coordinates
- [ ] **GPS Trail/History**: Record and display path taken
- [ ] **GNSS Corrections**: RTK mode for cm-level accuracy
- [ ] **Bearing & Distance**: Calculate to target waypoint
- [ ] **GPS Logging**: Export tracks to GPX/KML format
- [ ] **Geofencing**: Alert when entering/exiting zones
- [ ] **Dead Reckoning**: Estimate position during signal loss

### Possible Improvements

- [ ] Add magnetic compass heading
- [ ] Implement multi-constellation support (GLONASS, Galileo)
- [ ] Cache past positions for path history
- [ ] Add terrain elevation data overlay
- [ ] Integrate with mapping APIs (Google Maps, OpenStreetMap)

---

## References

### Documentation
- **TinyGPS++**: https://github.com/mikalhart/TinyGPS
- **NEO-6M Datasheet**: https://www.u-blox.com/en/product/neo-6-series
- **NMEA-0183 Protocol**: https://en.wikipedia.org/wiki/NMEA_0183

### Related Files
- **ESP32 Code**: `rover_app/lib/rover/rover.ino`
- **GPS Screen**: `rover_app/lib/rover/screens/gps_screen.dart`
- **RoverProvider**: `rover_app/lib/rover/providers/rover_provider.dart`
- **GPS Model**: `rover_app/lib/rover/models/rover_model.dart`

### Support Resources
- **Forum**: https://github.com/mikalhart/TinyGPS/discussions
- **u-blox Support**: https://www.u-blox.com/en/support
- **Arduino Community**: https://forum.arduino.cc/

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-20 | Initial GPS integration release |

---

## License

This GPS integration is part of the Agri Chain project and follows the same license terms.

---

**Last Updated**: February 20, 2026  
**Author**: Development Team  
**Status**: ✅ Production Ready
