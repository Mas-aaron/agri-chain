// ============================================
// ESP32 ROVER CONTROL SYSTEM - BOARD CODE
// Full version with WiFi, Bluetooth, Web Interface
// Compatible with D0-D3 Motor Driver
// ============================================

#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <BluetoothSerial.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <TinyGPS++.h>  // GPS library

#include <ESP32Servo.h>  // Servo library for soil sampling

// ============== PIN DEFINITIONS ==============
// Motor Driver Pins - D0-D3 Control
#define D0 18  // Motor 1 control A
#define D1 19  // Motor 1 control B
#define D2 21  // Motor 2 control A
#define D3 22  // Motor 2 control B

// Optional Features
#define LED_BUILTIN 2
#define BATTERY_PIN 34  // ADC pin for battery monitoring (optional)

// GPS Module Pins (Serial2 UART)
#define GPS_RX 16  // RX pin for GPS module
#define GPS_TX 17  // TX pin for GPS module
#define GPS_BAUD 9600  // Standard GPS module baud rate

// NPK Sensor Pins (RS485 to TTL - Serial1 UART)
#define NPK_RX 13      // RO (Receive Out) - Safe pin
#define NPK_TX 14      // DI (Data In) - Safe pin
#define NPK_DE_RE 27   // DE & RE connected together - Safe pin
#define NPK_BAUD 4800  // NPK sensor default baud rate

// ============== WIFI CONFIGURATION ==============
const char* ssid = "ESP32_Rover";
const char* password = "12345678";
const char* hostname = "esp32-rover";
IPAddress localIP(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress subnet(255, 255, 255, 0);

const char* staSsid = "MMU_Student";  // replace with your STA WiFi SSID
const char* staPassword = "student2018";  // replace with your STA WiFi password

// ============== BLUETOOTH CONFIGURATION ==============
BluetoothSerial SerialBT;
const char* btName = "ESP32_Rover_BT";

// ============== GPS CONFIGURATION ==============
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);  // Serial2 for GPS module

// GPS Data variables
struct {
  double latitude = 0.0;
  double longitude = 0.0;
  double altitude = 0.0;
  double speed = 0.0;  // in m/s
  double course = 0.0;  // heading direction
  int satellites = 0;
  double hdop = 99.99;  // horizontal dilution of precision
  unsigned long timestamp = 0;
  bool isValid = false;
  unsigned long lastReceivedTime = 0;  // When last valid fix was received
  unsigned long lastRequestTime = 0;   // When last /api/gps/data was requested
  int requestCount = 0;                // Number of GPS requests
  int dataUpdates = 0;                 // Number of position updates received
} gpsData;

unsigned long gpsLastByteTime = 0;
unsigned long gpsLastHeartbeatTime = 0;

// ============== NPK SENSOR CONFIGURATION ==============
HardwareSerial npkSerial(1); // Serial1 for RS485 module

struct {
  float moisture = 0.0;
  float temperature = 0.0;
  float ec = 0.0;
  float ph = 0.0;
  float nitrogen = 0.0;
  float phosphorus = 0.0;
  float potassium = 0.0;
  unsigned long lastReadTime = 0;
  bool isValid = false;
} npkData;

// Modbus RTU Queries for 7-in-1 sensor
// Standard registers: 0x0000 -> 0x0003 (Moist, Temp, EC, pH)
const byte queryEnv[] = {0x01, 0x03, 0x00, 0x00, 0x00, 0x04, 0x44, 0x09};

// Scanner revealed NPK actually starts at 0x0022 (Dec 34) on this specific clone
// N is at 0x22, P is at 0x23, K is at 0x24 (using 0x0022)
const byte queryNPK[] = {0x01, 0x03, 0x00, 0x22, 0x00, 0x03, 0xA5, 0xC1};

unsigned long npkLastUpdate = 0;
const unsigned long NPK_UPDATE_INTERVAL_MS = 5000; // Read sensor every 5 seconds
int currentQueryStep = 0; // 0 = Env, 1 = NPK

uint16_t modbusCrc16(const uint8_t* data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; i++) {
    crc ^= (uint16_t)data[i];
    for (int j = 0; j < 8; j++) {
      if (crc & 0x0001) {
        crc >>= 1;
        crc ^= 0xA001;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc;
}

void buildReadHoldingQuery(uint8_t slave, uint16_t startReg, uint16_t count, uint8_t* out8) {
  out8[0] = slave;
  out8[1] = 0x03;
  out8[2] = (startReg >> 8) & 0xFF;
  out8[3] = startReg & 0xFF;
  out8[4] = (count >> 8) & 0xFF;
  out8[5] = count & 0xFF;
  uint16_t crc = modbusCrc16(out8, 6);
  out8[6] = crc & 0xFF;
  out8[7] = (crc >> 8) & 0xFF;
}

bool readModbusFrame(uint8_t* frame, size_t frameMax, size_t* outLen, uint16_t timeoutMs) {
  *outLen = 0;
  unsigned long start = millis();
  while (millis() - start < timeoutMs) {
    if (npkSerial.available()) {
      uint8_t b = (uint8_t)npkSerial.read();
      if (*outLen < frameMax) {
        frame[(*outLen)++] = b;
      }
      if (*outLen >= 3) {
        if (frame[0] != 0x01 || frame[1] != 0x03) {
          continue;
        }
        uint8_t byteCount = frame[2];
        size_t expected = (size_t)3 + (size_t)byteCount + 2;
        if (expected > frameMax) {
          return false;
        }
        if (*outLen >= expected) {
          uint16_t crcCalc = modbusCrc16(frame, expected - 2);
          uint16_t crcRx = (uint16_t)frame[expected - 2] | ((uint16_t)frame[expected - 1] << 8);
          *outLen = expected;
          return crcCalc == crcRx;
        }
      }
    }
  }
  return false;
}

// ============== SOIL SAMPLING ==============
Servo servo1;  // Sampling arm servo
Servo servo2;  // Sampling bucket servo
const int SERVO1_PIN = 25;  // GPIO 25 for servo 1
const int SERVO2_PIN = 26;  // GPIO 26 for servo 2
const int SAMPLE_ANGLE_MIN = 0;
const int SAMPLE_ANGLE_MAX = 90;
bool isSampling = false;
unsigned long samplingStartTime = 0;

// ============== PATH RECORDING & NAVIGATION ==============
#define MAX_WAYPOINTS 100
#define RECORDING_INTERVAL_MS 2000  // Record waypoint every 2 seconds
#define MIN_DISTANCE_METERS 5.0     // Minimum distance between waypoints

struct Waypoint {
  double latitude;
  double longitude;
  double altitude;
  unsigned long timestamp;
  int index;
};

struct Route {
  char name[32];
  Waypoint waypoints[MAX_WAYPOINTS];
  int waypointCount;
  unsigned long createdAt;
};

// Active recording/navigation state
bool isRecording = false;
unsigned long lastRecordingTime = 0;
Waypoint recordedWaypoints[MAX_WAYPOINTS];
int recordedWaypointCount = 0;

// Navigation state
bool isNavigating = false;
int currentRouteIndex = 0;
int currentWaypointIndex = 0;
Route activeRoute;
double navigationTolerance = 10.0;  // meters

// ============== WEB SERVER ==============
WebServer server(80);

// ============== AGRICHAIN BACKEND ==============
const char* agrichainBaseUrl = "http://101.44.10.153:8000";
const char* roverDeviceId = "rover-01";
unsigned long lastBackendPost = 0;
const unsigned long BACKEND_POST_INTERVAL_MS = 10000;  // Send GPS every 10 seconds

// ============== MQTT ==============
WiFiClientSecure wifiClient;
PubSubClient mqttClient(wifiClient);
const char* iotdaDeviceId = "69997692610343162ba3eb80_b0-cb-d8-89-db-30";  // replace with your IoTDA device ID
const char* mqttHost = "dee43b65c8.st1.iotda-device.sa-brazil-1.myhuaweicloud.com";  // replace with your IoTDA host
uint16_t mqttPort = 8883;
const char* mqttUser = "69997692610343162ba3eb80_b0-cb-d8-89-db-30";  // replace with your IoTDA user
const char* mqttPass = "a338c7811198ffdd9423b2977aab001abf8f62b9883a4c2ade69cdee50568842";  // replace with your IoTDA password
const bool mqttTlsInsecure = true;
unsigned long lastMqttPublish = 0;
const unsigned long MQTT_PUBLISH_INTERVAL_MS = 1000;

// ============== SYSTEM VARIABLES ==============
// Movement state
String currentCommand = "stop";
String currentDirection = "none";
bool isMoving = false;
unsigned long commandStartTime = 0;
int motorSpeed = 255;  // Fixed for your driver

// System state
unsigned long systemUptime = 0;
int wifiClients = 0;
int batteryLevel = 100;
String lastError = "";

// Timing constants
const unsigned long COMMAND_TIMEOUT = 30000;     // 30 seconds auto-stop
const unsigned long HEARTBEAT_INTERVAL = 1000;   // 1 second
const unsigned long STATUS_UPDATE_INTERVAL = 500; // 0.5 second

// Command queue
String btCommand = "";
String lastCommandSource = "none";

// ============== SETUP ==============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  printBootScreen();
  
  // Initialize all systems
  initPins();
  initGPS();
  initNPKSensor();
  initServos();
  initBluetooth();
  initWiFi();
  initMQTT();
  
  // Initial state
  stopMotors();
  
  printSystemInfo();
}

void initPins() {
  Serial.print(F("Initializing pins..."));
  
  // Motor control pins
  pinMode(D0, OUTPUT);
  pinMode(D1, OUTPUT);
  pinMode(D2, OUTPUT);
  pinMode(D3, OUTPUT);
  
  // Status LED
  pinMode(LED_BUILTIN, OUTPUT);
  
  // Battery monitoring (optional)
  pinMode(BATTERY_PIN, INPUT);
  
  // Set initial states
  digitalWrite(D0, LOW);
  digitalWrite(D1, LOW);
  digitalWrite(D2, LOW);
  digitalWrite(D3, LOW);
  digitalWrite(LED_BUILTIN, LOW);
  
  Serial.println(F(" ✓"));
}

void initGPS() {
  Serial.print(F("Initializing GPS module..."));
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println(F(" ✓"));
  Serial.println(F("  └─ Baud Rate: 9600"));
  Serial.println(F("  └─ Listening for satellite data..."));
}

void initNPKSensor() {
  Serial.print(F("Initializing NPK Sensor..."));
  
  pinMode(NPK_DE_RE, OUTPUT);
  digitalWrite(NPK_DE_RE, LOW); // Start in receive mode
  
  // Some TTL to RS485 modules (MAX485 clones) have inverted logic levels on the ESP32
  // If the standard configuration produces FF FF FF, we try inverting the RX/TX signals
  // bool invert = false; (standard) -> change to true if it still outputs FF
  npkSerial.begin(NPK_BAUD, SERIAL_8N1, NPK_RX, NPK_TX, false);
  
  Serial.println(F(" ✓"));
  Serial.println(F("  └─ Baud Rate: 4800"));
  Serial.println(F("  └─ RS485 DE/RE: GPIO 27"));
}

void initServos() {
  Serial.print(F("Initializing soil sampling servos..."));
  
  // Allocate timers for ESP32Servo (supports up to 4 servos)
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  
  // Attach servos with 50 Hz frequency
  servo1.setPeriodHertz(50);
  servo1.attach(SERVO1_PIN, 500, 2400);
  servo2.setPeriodHertz(50);
  servo2.attach(SERVO2_PIN, 500, 2400);
  
  // Set initial positions to 0°
  servo1.write(SAMPLE_ANGLE_MIN);
  servo2.write(SAMPLE_ANGLE_MIN);
  
  Serial.println(F(" ✓"));
  Serial.println(F("  └─ Servo 1: GPIO 25"));
  Serial.println(F("  └─ Servo 2: GPIO 26"));
}

void initWiFi() {
  Serial.print(F("Connecting STA WiFi..."));
 
  WiFi.mode(WIFI_STA);
  WiFi.begin(staSsid, staPassword);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && (millis() - start) < 15000) {
    delay(250);
    Serial.print('.');
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(F(" ✓"));
    Serial.print(F("  └─ STA IP: "));
    Serial.println(WiFi.localIP());
  } else {
    Serial.println(F(" ✗"));
  }
}

void initMQTT() {
  if (mqttTlsInsecure) {
    wifiClient.setInsecure();
  }
  mqttClient.setServer(mqttHost, mqttPort);
  mqttClient.setCallback(mqttCallback);
}

void handleMQTT() {
  if (strlen(mqttHost) == 0) return;
  if (WiFi.status() != WL_CONNECTED) return;

  if (!mqttClient.connected()) {
    ensureMqttConnected();
  }
  mqttClient.loop();

  if (gpsData.isValid && mqttClient.connected()) {
    if (millis() - lastMqttPublish >= MQTT_PUBLISH_INTERVAL_MS) {
      publishGpsTelemetry();
      lastMqttPublish = millis();
    }
  }
}

void ensureMqttConnected() {
  String clientId = String(hostname) + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);

  bool ok = false;
  if (strlen(mqttUser) > 0) {
    ok = mqttClient.connect(clientId.c_str(), mqttUser, mqttPass);
  } else {
    ok = mqttClient.connect(clientId.c_str());
  }
  if (ok) {
    String cmdTopic = String("$oc/devices/") + iotdaDeviceId + "/sys/commands/#";
    mqttClient.subscribe(cmdTopic.c_str());
  }
}

void publishGpsTelemetry() {
  StaticJsonDocument<384> doc;
  JsonArray services = doc.createNestedArray("services");
  JsonObject svc = services.createNestedObject();
  svc["service_id"] = "Rover";
  JsonObject props = svc.createNestedObject("properties");
  props["lat"] = gpsData.latitude;
  props["lon"] = gpsData.longitude;
  props["alt"] = gpsData.altitude;
  props["speed"] = gpsData.speed;
  props["course"] = gpsData.course;
  props["sat"] = gpsData.satellites;
  props["hdop"] = gpsData.hdop;
  
  // Attach NPK data if valid
  if (npkData.isValid) {
    props["nitrogen"] = npkData.nitrogen;
    props["phosphorus"] = npkData.phosphorus;
    props["potassium"] = npkData.potassium;
    props["moisture"] = npkData.moisture;
    props["temperature"] = npkData.temperature;
    props["ec"] = npkData.ec;
    props["ph"] = npkData.ph;
  }

  char payload[512];
  size_t n = serializeJson(doc, payload, sizeof(payload));
  if (n == 0) return;

  String topic = String("$oc/devices/") + iotdaDeviceId + "/sys/properties/report";
  mqttClient.publish(topic.c_str(), payload);
}

// ============== AGRICHAIN BACKEND HTTP POST ==============
void postSensorDataToBackend() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (!gpsData.isValid) return;
  if (millis() - lastBackendPost < BACKEND_POST_INTERVAL_MS) return;

  lastBackendPost = millis();

  HTTPClient http;
  String url = String(agrichainBaseUrl) + "/sensor-data";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  // Build JSON payload
  StaticJsonDocument<384> doc;
  doc["device_id"] = roverDeviceId;
  doc["latitude"] = gpsData.latitude;
  doc["longitude"] = gpsData.longitude;
  doc["altitude"] = gpsData.altitude;
  doc["speed"] = gpsData.speed;
  doc["course"] = gpsData.course;
  doc["satellites"] = gpsData.satellites;
  doc["hdop"] = gpsData.hdop;
  
  // Add NPK fields if sensor has valid reading
  if (npkData.isValid) {
    doc["nitrogen"] = npkData.nitrogen;
    doc["phosphorus"] = npkData.phosphorus;
    doc["potassium"] = npkData.potassium;
    doc["temperature"] = npkData.temperature;
    doc["humidity"] = npkData.moisture; // Map moisture to humidity for backend
    doc["ph"] = npkData.ph;
    doc["ec"] = npkData.ec;
  }

  char payload[512];
  serializeJson(doc, payload, sizeof(payload));

  int httpCode = http.POST(payload);

  if (httpCode == 201) {
    Serial.print(F("📤 Backend POST OK → Lat="));
    Serial.print(gpsData.latitude, 6);
    Serial.print(F(" Lon="));
    Serial.println(gpsData.longitude, 6);
  } else {
    Serial.print(F("❌ Backend POST failed: "));
    Serial.println(httpCode);
  }

  http.end();
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  if (length == 0) return;

  StaticJsonDocument<2048> doc;
  DeserializationError err = deserializeJson(doc, payload, length);
  if (err) return;

  String t(topic);

  String cmdPrefix = String("$oc/devices/") + iotdaDeviceId + "/sys/commands/";
  if (!t.startsWith(cmdPrefix)) return;

  int idx = t.indexOf("request_id=");
  String requestId = idx >= 0 ? t.substring(idx + 11) : "";

  String commandName = doc.containsKey("command_name") ? doc["command_name"].as<String>() : "";
  JsonObject paras = doc["paras"].as<JsonObject>();
  bool handled = false;
  int resultCode = 0;

  if (commandName == "MOVE") {
    if (paras.containsKey("command")) {
      String cmd = paras["command"].as<String>();
      cmd.trim();
      cmd.toLowerCase();
      executeCommand(cmd, "MQTT");
      handled = true;
    }
  } else if (commandName == "SET_ROUTE") {
    JsonArray waypoints = paras["waypoints"].as<JsonArray>();
    StaticJsonDocument<3072> routeDoc;

    if (waypoints.isNull() && paras.containsKey("route_json")) {
      const char* routeJson = paras["route_json"].as<const char*>();
      if (routeJson && strlen(routeJson) > 0) {
        DeserializationError rerr = deserializeJson(routeDoc, routeJson);
        if (!rerr) {
          waypoints = routeDoc["waypoints"].as<JsonArray>();
        }
      }
    }

    if (!waypoints.isNull()) {
      int count = 0;
      for (JsonVariant v : waypoints) {
        if (count >= MAX_WAYPOINTS) break;
        JsonObject wp = v.as<JsonObject>();
        if (!wp.containsKey("lat") || !wp.containsKey("lon")) continue;
        activeRoute.waypoints[count].latitude = wp["lat"].as<double>();
        activeRoute.waypoints[count].longitude = wp["lon"].as<double>();
        activeRoute.waypoints[count].altitude = wp.containsKey("alt") ? wp["alt"].as<double>() : 0.0;
        activeRoute.waypoints[count].timestamp = millis();
        activeRoute.waypoints[count].index = count;
        count++;
      }
      if (count > 0) {
        activeRoute.createdAt = millis();
        activeRoute.waypointCount = count;

        if (paras.containsKey("tolerance")) {
          navigationTolerance = paras["tolerance"].as<double>();
        } else if (!routeDoc.isNull() && routeDoc.containsKey("tolerance")) {
          navigationTolerance = routeDoc["tolerance"].as<double>();
        }

        bool start = paras.containsKey("start") ? paras["start"].as<bool>() : true;
        if (!routeDoc.isNull() && routeDoc.containsKey("start")) {
          start = routeDoc["start"].as<bool>();
        }
        if (start && gpsData.isValid) {
          isNavigating = true;
          currentWaypointIndex = 0;
        }
        handled = true;
      }
    }
  }

  if (!handled) {
    resultCode = 1;
  }

  if (requestId.length() > 0 && mqttClient.connected()) {
    String respTopic = String("$oc/devices/") + iotdaDeviceId + "/sys/commands/response/request_id=" + requestId;
    StaticJsonDocument<256> resp;
    resp["result_code"] = resultCode;
    resp["response_name"] = "COMMAND_RESPONSE";
    JsonObject rparas = resp.createNestedObject("paras");
    rparas["result"] = resultCode == 0 ? "success" : "fail";

    char respPayload[256];
    size_t rn = serializeJson(resp, respPayload, sizeof(respPayload));
    if (rn > 0) {
      mqttClient.publish(respTopic.c_str(), respPayload);
    }
  }
}

void initBluetooth() {
  Serial.print(F("Starting Bluetooth..."));
  SerialBT.begin(btName);
  Serial.println(F(" ✓"));
  Serial.print(F("  └─ Device: "));
  Serial.println(btName);
}

void initWebServer() {
  Serial.print(F("Starting Web Server..."));
  
  // ===== API Endpoints =====
  
  // Root - Web Interface
  server.on("/", HTTP_GET, handleRoot);
  
  // Status endpoints
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/info", HTTP_GET, handleInfo);
  server.on("/api/npk", HTTP_GET, handleNPKData);
  
  // Movement endpoints (full words)
  server.on("/api/forward", HTTP_GET, handleForward);
  server.on("/api/backward", HTTP_GET, handleBackward);
  server.on("/api/left", HTTP_GET, handleLeft);
  server.on("/api/right", HTTP_GET, handleRight);
  server.on("/api/rotate-left", HTTP_GET, handleRotateLeft);
  server.on("/api/rotate-right", HTTP_GET, handleRotateRight);
  server.on("/api/stop", HTTP_GET, handleStop);
  
  // Short endpoints for efficiency
  server.on("/f", HTTP_GET, handleForward);
  server.on("/b", HTTP_GET, handleBackward);
  server.on("/l", HTTP_GET, handleLeft);
  server.on("/r", HTTP_GET, handleRight);
  server.on("/rl", HTTP_GET, handleRotateLeft);
  server.on("/rr", HTTP_GET, handleRotateRight);
  server.on("/s", HTTP_GET, handleStop);
  
  // Speed control (for compatibility)
  server.on("/api/speed", HTTP_GET, handleSpeed);
  
  // System control
  server.on("/api/reboot", HTTP_GET, handleReboot);
  
  // GPS endpoints
  server.on("/api/gps/data", HTTP_GET, handleGPS);
  server.on("/gps", HTTP_GET, handleGPS);  // Shortcut
  
  // Soil sampling endpoint
  server.on("/api/sample/soil", HTTP_GET, handleSoilSample);
  server.on("/sample", HTTP_GET, handleSoilSample);  // Shortcut
  
  // Path recording endpoints
  server.on("/api/recording/start", HTTP_GET, handleRecordingStart);
  server.on("/api/recording/stop", HTTP_GET, handleRecordingStop);
  server.on("/api/recording/data", HTTP_GET, handleRecordingData);
  server.on("/api/recording/save", HTTP_POST, handleSaveRoute);
  
  // Navigation endpoints
  server.on("/api/navigation/start", HTTP_GET, handleNavigationStart);
  server.on("/api/navigation/stop", HTTP_GET, handleNavigationStop);
  server.on("/api/navigation/status", HTTP_GET, handleNavigationStatus);
  
  server.begin();
  Serial.println(F(" ✓"));
  Serial.println(F("  └─ URL: http://192.168.4.1"));
}

// ============== MAIN LOOP ==============
void loop() {
  handleBluetooth();          // Handle Bluetooth commands
  updateGPS();                // Read GPS data
  updateNPKSensor();          // Read NPK soil sensor
  handleMQTT();               // Huawei IoT MQTT
  postSensorDataToBackend();  // AgriChain backend HTTP POST
  updateSystemStatus();       // Update system status
  runHeartbeat();             // LED indicator
  
  // Handle soil sampling if in progress
  if (isSampling) {
    executeSoilSampling();
  }
  
  // Handle path recording
  if (isRecording && gpsData.isValid) {
    recordPathWaypoint();
  }
  
  // Handle autonomous navigation
  if (isNavigating) {
    executeAutonomousNavigation();
  }
  
  delay(10);  // Small delay for stability
}

// ============== WEB INTERFACE ==============
void handleRoot() {
  String html = generateHTML();
  server.send(200, "text/html", html);
}

void handleStatus() {
  StaticJsonDocument<256> doc;
  
  doc["command"] = currentCommand;
  doc["direction"] = currentDirection;
  doc["isMoving"] = isMoving;
  doc["speed"] = motorSpeed;
  doc["battery"] = readBatteryLevel();
  doc["uptime"] = millis() / 1000;
  doc["clients"] = WiFi.softAPgetStationNum();
  doc["source"] = lastCommandSource;
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleInfo() {
  StaticJsonDocument<1024> doc;
  
  doc["name"] = "ESP32 Rover Control System";
  doc["version"] = "2.0.0";
  doc["build"] = "with_recording_endpoints";
  doc["board"] = "ESP32-WROOM-32D";
  doc["driver"] = "D0-D3 Motor Driver";
  doc["wifi_ssid"] = ssid;
  doc["wifi_ip"] = WiFi.softAPIP().toString();
  doc["bluetooth"] = btName;
  doc["features"] = "WiFi AP, Bluetooth, Web UI, REST API";
  
  JsonArray endpoints = doc.createNestedArray("endpoints");
  endpoints.add("GET /api/status");
  endpoints.add("GET /api/info");
  endpoints.add("GET /api/npk");
  endpoints.add("GET /api/gps/data");
  endpoints.add("GET /api/forward");
  endpoints.add("GET /api/backward");
  endpoints.add("GET /api/left");
  endpoints.add("GET /api/right");
  endpoints.add("GET /api/rotate-left");
  endpoints.add("GET /api/rotate-right");
  endpoints.add("GET /api/stop");
  endpoints.add("GET /api/speed?value=0-255");
  endpoints.add("GET /f (shortcut forward)");
  endpoints.add("GET /b (shortcut backward)");
  endpoints.add("GET /l (shortcut left)");
  endpoints.add("GET /r (shortcut right)");
  endpoints.add("GET /rl (shortcut rotate-left)");
  endpoints.add("GET /rr (shortcut rotate-right)");
  endpoints.add("GET /s (shortcut stop)");
  endpoints.add("GET /gps (shortcut for GPS data)");
  endpoints.add("GET /api/recording/start");
  endpoints.add("GET /api/recording/stop");
  endpoints.add("GET /api/recording/data");
  endpoints.add("POST /api/recording/save?name=<routeName>");
  endpoints.add("GET /api/navigation/start");
  endpoints.add("GET /api/navigation/stop");
  endpoints.add("GET /api/navigation/status");
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// ============== API HANDLERS ==============
void handleForward() { executeCommand("forward", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"forward\"}"); }
void handleBackward() { executeCommand("backward", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"backward\"}"); }
void handleLeft() { executeCommand("left", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"left\"}"); }
void handleRight() { executeCommand("right", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"right\"}"); }
void handleRotateLeft() { executeCommand("rotate-left", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"rotate-left\"}"); }
void handleRotateRight() { executeCommand("rotate-right", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"rotate-right\"}"); }
void handleStop() { executeCommand("stop", "WiFi"); server.send(200, "application/json", "{\"status\":\"ok\",\"command\":\"stop\"}"); }

void handleSpeed() {
  if (server.hasArg("value")) {
    int speed = server.arg("value").toInt();
    setSpeed(speed);
  }
  server.send(200, "application/json", "{\"status\":\"ok\",\"speed\":" + String(motorSpeed) + "}");
}

void handleReboot() {
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Rebooting...\"}");
  delay(1000);
  ESP.restart();
}

void handleGPS() {
  // Track request
  gpsData.lastRequestTime = millis();
  gpsData.requestCount++;
  
  // Build minimal JSON manually to avoid serialization issues
  String response = "{";
  response += "\"latitude\":" + String(gpsData.latitude, 6) + ",";
  response += "\"longitude\":" + String(gpsData.longitude, 6) + ",";
  response += "\"altitude\":" + String(gpsData.altitude, 2) + ",";
  response += "\"speed\":" + String(gpsData.speed, 2) + ",";
  response += "\"course\":" + String(gpsData.course, 2) + ",";
  response += "\"satellites\":" + String(gpsData.satellites) + ",";
  response += "\"hdop\":" + String(gpsData.hdop, 2) + ",";
  response += "\"timestamp\":" + String((unsigned long)millis()) + ",";
  response += "\"is_valid\":" + String(gpsData.isValid ? "true" : "false");
  response += "}";
  
  server.send(200, "application/json", response);
  
  // Log request with formatted GPS data
  Serial.print(F("📡 GPS API Request #"));
  Serial.print(gpsData.requestCount);
  if (gpsData.isValid) {
    Serial.print(F(" ✓ → Lat: "));
    Serial.print(gpsData.latitude, 6);
    Serial.print(F(", Lon: "));
    Serial.print(gpsData.longitude, 6);
    Serial.print(F(", Sats: "));
    Serial.print(gpsData.satellites);
    Serial.print(F(", HDOP: "));
    Serial.println(gpsData.hdop, 2);
  } else {
    Serial.println(F(" ✗ → NO FIX (searching)"));
  }
}

void handleNPKData() {
  String response = "{";
  response += "\"moisture\":" + String(npkData.moisture, 1) + ",";
  response += "\"temperature\":" + String(npkData.temperature, 1) + ",";
  response += "\"ec\":" + String(npkData.ec, 0) + ",";
  response += "\"ph\":" + String(npkData.ph, 1) + ",";
  response += "\"nitrogen\":" + String(npkData.nitrogen, 0) + ",";
  response += "\"phosphorus\":" + String(npkData.phosphorus, 0) + ",";
  response += "\"potassium\":" + String(npkData.potassium, 0) + ",";
  response += "\"timestamp\":" + String((unsigned long)millis()) + ",";
  response += "\"is_valid\":" + String(npkData.isValid ? "true" : "false");
  response += "}";
  
  server.send(200, "application/json", response);
}

void handleSoilSample() {
  if (isSampling) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Sampling already in progress\"}");
    return;
  }
  
  // Start soil sampling sequence
  isSampling = true;
  samplingStartTime = millis();
  
  Serial.println(F("\n🌱 SOIL SAMPLING INITIATED"));
  Serial.println(F("═════════════════════════"));
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Soil sampling started\"}");
  
  // Execute sampling sequence (non-blocking, handled in loop)
}

// ============== PATH RECORDING HANDLERS ==============
void handleRecordingStart() {
  if (isRecording) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Recording already in progress\"}");
    return;
  }
  
  if (!gpsData.isValid) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No GPS fix, cannot start recording\"}");
    return;
  }
  
  isRecording = true;
  recordedWaypointCount = 0;
  lastRecordingTime = millis();
  
  Serial.println(F("\n📍 PATH RECORDING STARTED"));
  Serial.println(F("═════════════════════════"));
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Path recording started\"}");
}

void handleRecordingStop() {
  if (!isRecording) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No recording in progress\"}");
    return;
  }
  
  isRecording = false;
  
  Serial.print(F("[✓] Recording stopped. Waypoints captured: "));
  Serial.println(recordedWaypointCount);
  Serial.println(F("═════════════════════════\n"));
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Path recording stopped\",\"waypoints\":" + String(recordedWaypointCount) + "}");
}

void handleRecordingData() {
  // Return all recorded waypoints as JSON array
  String response = "{\"recording\":" + String(isRecording ? "true" : "false") + ",\"waypoints\":[";
  
  for (int i = 0; i < recordedWaypointCount; i++) {
    if (i > 0) response += ",";
    response += "{";
    response += "\"index\":" + String(i) + ",";
    response += "\"latitude\":" + String(recordedWaypoints[i].latitude, 8) + ",";
    response += "\"longitude\":" + String(recordedWaypoints[i].longitude, 8) + ",";
    response += "\"altitude\":" + String(recordedWaypoints[i].altitude, 2) + ",";
    response += "\"timestamp\":" + String(recordedWaypoints[i].timestamp);
    response += "}";
  }
  
  response += "],\"total\":" + String(recordedWaypointCount) + "}";
  server.send(200, "application/json", response);
}

void handleSaveRoute() {
  if (recordedWaypointCount == 0) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No waypoints to save\"}");
    return;
  }
  
  // Get route name from POST data
  String routeName = "Route_" + String(millis() / 1000);
  if (server.hasArg("name")) {
    routeName = server.arg("name");
  }
  
  // Save route to memory
  activeRoute.createdAt = millis();
  activeRoute.waypointCount = recordedWaypointCount;
  strcpy(activeRoute.name, routeName.c_str());
  
  for (int i = 0; i < recordedWaypointCount; i++) {
    activeRoute.waypoints[i] = recordedWaypoints[i];
  }
  
  // Clear recording for next session
  recordedWaypointCount = 0;
  
  Serial.print(F("✅ Route saved: "));
  Serial.print(routeName);
  Serial.print(F(" with "));
  Serial.print(activeRoute.waypointCount);
  Serial.println(F(" waypoints"));
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Route saved\",\"name\":\"" + routeName + "\",\"waypoints\":" + String(activeRoute.waypointCount) + "}");
}

// ============== NAVIGATION HANDLERS ==============
void handleNavigationStart() {
  if (isNavigating) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Navigation already in progress\"}");
    return;
  }
  
  if (activeRoute.waypointCount == 0) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No route loaded\"}");
    return;
  }
  
  if (!gpsData.isValid) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No GPS fix, cannot start navigation\"}");
    return;
  }
  
  isNavigating = true;
  currentWaypointIndex = 0;
  
  Serial.println(F("\n🗺️  AUTONOMOUS NAVIGATION STARTED"));
  Serial.println(F("═════════════════════════"));
  Serial.print(F("Route: "));
  Serial.print(activeRoute.name);
  Serial.print(F(" | Waypoints: "));
  Serial.println(activeRoute.waypointCount);
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Navigation started\"}");
}

void handleNavigationStop() {
  if (!isNavigating) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No navigation in progress\"}");
    return;
  }
  
  isNavigating = false;
  stopMotors();
  
  Serial.println(F("[✓] Navigation stopped"));
  Serial.println(F("═════════════════════════\n"));
  
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Navigation stopped\"}");
}

void handleNavigationStatus() {
  String response = "{";
  response += "\"navigating\":" + String(isNavigating ? "true" : "false") + ",";
  response += "\"currentWaypoint\":" + String(currentWaypointIndex) + ",";
  response += "\"totalWaypoints\":" + String(activeRoute.waypointCount) + ",";
  response += "\"routeName\":\"" + String(activeRoute.name) + "\"";
  
  if (isNavigating && currentWaypointIndex < activeRoute.waypointCount) {
    Waypoint target = activeRoute.waypoints[currentWaypointIndex];
    double distance = calculateDistance(gpsData.latitude, gpsData.longitude, target.latitude, target.longitude);
    
    response += ",\"targetLat\":" + String(target.latitude, 8);
    response += ",\"targetLon\":" + String(target.longitude, 8);
    response += ",\"distanceToTarget\":" + String(distance, 2);
    response += ",\"targetReached\":" + String(distance < navigationTolerance ? "true" : "false");
    response += ",\"bearing\":" + String(calculateBearing(gpsData.latitude, gpsData.longitude, target.latitude, target.longitude), 2);
  }
  
  response += "}";
  server.send(200, "application/json", response);
}

// ============== BLUETOOTH HANDLING ==============
void handleBluetooth() {
  if (!SerialBT.available()) return;
  
  char c = SerialBT.read();
  
  if (c == '\n' || c == '\r') {
    if (btCommand.length() > 0) {
      processBluetoothCommand(btCommand);
      btCommand = "";
    }
  } else {
    btCommand += c;
  }
}

void processBluetoothCommand(String cmd) {
  cmd.trim();
  cmd.toLowerCase();
  
  Serial.print(F("📱 BT Cmd: "));
  Serial.println(cmd);
  
  // Movement commands
  if (cmd == "forward" || cmd == "f") {
    executeCommand("forward", "Bluetooth");
  }
  else if (cmd == "backward" || cmd == "b") {
    executeCommand("backward", "Bluetooth");
  }
  else if (cmd == "left" || cmd == "l") {
    executeCommand("left", "Bluetooth");
  }
  else if (cmd == "right" || cmd == "r") {
    executeCommand("right", "Bluetooth");
  }
  else if (cmd == "rotate-left" || cmd == "rl") {
    executeCommand("rotate-left", "Bluetooth");
  }
  else if (cmd == "rotate-right" || cmd == "rr") {
    executeCommand("rotate-right", "Bluetooth");
  }
  else if (cmd == "stop" || cmd == "s") {
    executeCommand("stop", "Bluetooth");
  }
  
  // System commands
  else if (cmd == "status") {
    sendBluetoothStatus();
  }
  else if (cmd == "help") {
    sendBluetoothHelp();
  }
  else if (cmd == "info") {
    sendBluetoothInfo();
  }
  else if (cmd == "gps") {
    sendBluetoothGPS();
  }
  else if (cmd == "sample") {
    if (isSampling) {
      SerialBT.println("❌ Sampling already in progress");
    } else {
      isSampling = true;
      samplingStartTime = millis();
      SerialBT.println("✓ Soil sampling started");
    }
  }

  else if (cmd == "npkscan") {
    SerialBT.println("NPK scan start");
    uint8_t q[8];
    uint8_t f[64];
    size_t flen = 0;

    for (uint16_t r = 0x0010; r <= 0x0030; r++) {
      while (npkSerial.available()) npkSerial.read();
      buildReadHoldingQuery(0x01, r, 3, q);

      digitalWrite(NPK_DE_RE, HIGH);
      delay(10);
      npkSerial.write(q, 8);
      npkSerial.flush();
      delay(4);
      digitalWrite(NPK_DE_RE, LOW);
      delay(5);

      bool ok = readModbusFrame(f, sizeof(f), &flen, 350);
      if (ok && flen >= 11 && f[2] == 0x06) {
        uint16_t v1 = ((uint16_t)f[3] << 8) | f[4];
        uint16_t v2 = ((uint16_t)f[5] << 8) | f[6];
        uint16_t v3 = ((uint16_t)f[7] << 8) | f[8];
        SerialBT.print("reg 0x");
        if (r < 0x1000) SerialBT.print("0");
        if (r < 0x0100) SerialBT.print("0");
        if (r < 0x0010) SerialBT.print("0");
        SerialBT.print(String(r, HEX));
        SerialBT.print(" -> ");
        SerialBT.print(v1);
        SerialBT.print(",");
        SerialBT.print(v2);
        SerialBT.print(",");
        SerialBT.println(v3);
      }
      delay(30);
    }
    SerialBT.println("NPK scan done");
  }
  
  // Speed command
  else if (cmd.startsWith("speed")) {
    int s = cmd.substring(5).toInt();
    setSpeed(s);
    SerialBT.print("✓ Speed set to: ");
    SerialBT.println(motorSpeed);
  }
  
  else {
    SerialBT.println("❌ Unknown command. Type 'help' for available commands.");
  }
}

void sendBluetoothStatus() {
  SerialBT.println("\n📊 SYSTEM STATUS");
  SerialBT.println("==================");
  SerialBT.print("Command:      "); SerialBT.println(currentCommand);
  SerialBT.print("Direction:    "); SerialBT.println(currentDirection);
  SerialBT.print("Moving:       "); SerialBT.println(isMoving ? "YES" : "NO");
  SerialBT.print("Speed:        "); SerialBT.println(motorSpeed);
  SerialBT.print("Battery:      "); SerialBT.print(readBatteryLevel()); SerialBT.println("%");
  SerialBT.print("Uptime:       "); SerialBT.print(millis() / 1000); SerialBT.println("s");
  SerialBT.print("WiFi Clients: "); SerialBT.println(WiFi.softAPgetStationNum());
  SerialBT.print("Source:       "); SerialBT.println(lastCommandSource);
  SerialBT.println("==================");
}

void sendBluetoothHelp() {
  SerialBT.println("\n📋 AVAILABLE COMMANDS");
  SerialBT.println("======================");
  SerialBT.println("MOVEMENT:");
  SerialBT.println("  f / forward     - Move forward");
  SerialBT.println("  b / backward    - Move backward");
  SerialBT.println("  l / left        - Turn left");
  SerialBT.println("  r / right       - Turn right");
  SerialBT.println("  rl / rotate-left - Rotate left (spin)");
  SerialBT.println("  rr / rotate-right - Rotate right (spin)");
  SerialBT.println("  s / stop        - Stop all motors");
  SerialBT.println("\nSYSTEM:");
  SerialBT.println("  status          - Show system status");
  SerialBT.println("  gps             - Show GPS data");
  SerialBT.println("  sample          - Sample soil");
  SerialBT.println("  info            - Show system info");
  SerialBT.println("  speed[0-255]    - Set speed (e.g., speed180)");
  SerialBT.println("  help            - Show this help");
  SerialBT.println("======================");
}

void sendBluetoothInfo() {
  SerialBT.println("\nℹ️ SYSTEM INFORMATION");
  SerialBT.println("======================");
  SerialBT.println("Name: ESP32 Rover Control System");
  SerialBT.println("Version: 2.0.0");
  SerialBT.println("Board: ESP32-WROOM-32D");
  SerialBT.println("Driver: D0-D3 Motor Driver");
  SerialBT.print("WiFi SSID: "); SerialBT.println(ssid);
  SerialBT.print("WiFi IP: "); SerialBT.println(WiFi.softAPIP());
  SerialBT.print("Bluetooth: "); SerialBT.println(btName);
  SerialBT.println("======================");
}

void sendBluetoothGPS() {
  SerialBT.println("\n📍 GPS DATA");
  SerialBT.println("==========================");
  
  if (!gpsData.isValid) {
    SerialBT.print("Status:       NO FIX");
    SerialBT.print(" (Searching");
    if (gpsData.satellites > 0) {
      SerialBT.print(" - ");
      SerialBT.print(gpsData.satellites);
      SerialBT.print(" sats");
    }
    SerialBT.println(")");
    SerialBT.println("==========================");
    return;
  }
  
  SerialBT.print("Status:       "); SerialBT.println(gpsData.isValid ? "VALID FIX ✓" : "NO FIX");
  SerialBT.print("Latitude:     "); SerialBT.println(gpsData.latitude, 8);
  SerialBT.print("Longitude:    "); SerialBT.println(gpsData.longitude, 8);
  SerialBT.print("Altitude:     "); SerialBT.print(gpsData.altitude, 2); SerialBT.println(" m");
  SerialBT.print("Speed:        "); SerialBT.print(gpsData.speed * 3.6, 2); SerialBT.println(" km/h");
  SerialBT.print("Course:       "); SerialBT.print(gpsData.course, 2); SerialBT.println("°");
  SerialBT.print("Satellites:   "); SerialBT.println(gpsData.satellites);
  SerialBT.print("HDOP:         "); SerialBT.println(gpsData.hdop, 2);
  
  // Signal quality assessment
  String quality = gpsData.hdop < 1 ? "Excellent" : 
                   gpsData.hdop < 2 ? "Good" : 
                   gpsData.hdop < 5 ? "Fair" : "Poor";
  SerialBT.print("Signal:       "); SerialBT.println(quality);
  
  SerialBT.print("Data Count:   "); SerialBT.println(gpsData.dataUpdates);
  SerialBT.println("==========================");
}

// ============== COMMAND EXECUTION ==============
void executeCommand(String command, String source) {
  currentCommand = command;
  lastCommandSource = source;
  commandStartTime = millis();
  
  // Log command
  Serial.print(F("⚡ "));
  Serial.print(source);
  Serial.print(F(" → "));
  Serial.println(command);
  
  // Execute appropriate movement
  if (command == "forward") {
    forward();
  }
  else if (command == "backward") {
    backward();
  }
  else if (command == "left") {
    turnLeft();
  }
  else if (command == "right") {
    turnRight();
  }
  else if (command == "rotate-left") {
    rotateLeft();
  }
  else if (command == "rotate-right") {
    rotateRight();
  }
  else if (command == "stop") {
    stopMotors();
  }
}

// ============== MOTOR CONTROL FUNCTIONS ==============
void forward() {
  currentDirection = "forward";
  isMoving = true;
  
  // Motor 1 forward: D0=HIGH, D1=LOW
  digitalWrite(D0, HIGH);
  digitalWrite(D1, LOW);
  
  // Motor 2 forward: D2=HIGH, D3=LOW
  digitalWrite(D2, HIGH);
  digitalWrite(D3, LOW);
  
  Serial.println(F("  ▶ FORWARD"));
}

void backward() {
  currentDirection = "backward";
  isMoving = true;
  
  // Motor 1 backward: D0=LOW, D1=HIGH
  digitalWrite(D0, LOW);
  digitalWrite(D1, HIGH);
  
  // Motor 2 backward: D2=LOW, D3=HIGH
  digitalWrite(D2, LOW);
  digitalWrite(D3, HIGH);
  
  Serial.println(F("  ◀ BACKWARD"));
}

void turnLeft() {
  currentDirection = "left";
  isMoving = true;
  
  // Left turn: stop left motor, run right motor forward
  digitalWrite(D0, LOW);  // Motor 1 stop
  digitalWrite(D1, LOW);
  
  digitalWrite(D2, HIGH); // Motor 2 forward
  digitalWrite(D3, LOW);
  
  Serial.println(F("  ↰ TURN LEFT"));
}

void turnRight() {
  currentDirection = "right";
  isMoving = true;
  
  // Right turn: run left motor forward, stop right motor
  digitalWrite(D0, HIGH); // Motor 1 forward
  digitalWrite(D1, LOW);
  
  digitalWrite(D2, LOW);  // Motor 2 stop
  digitalWrite(D3, LOW);
  
  Serial.println(F("  ↱ TURN RIGHT"));
}

void rotateLeft() {
  currentDirection = "rotate-left";
  isMoving = true;
  
  // Rotate left: left backward, right forward
  digitalWrite(D0, LOW);  // Motor 1 backward
  digitalWrite(D1, HIGH);
  
  digitalWrite(D2, HIGH); // Motor 2 forward
  digitalWrite(D3, LOW);
  
  Serial.println(F("  ↺ ROTATE LEFT"));
}

void rotateRight() {
  currentDirection = "rotate-right";
  isMoving = true;
  
  // Rotate right: left forward, right backward
  digitalWrite(D0, HIGH); // Motor 1 forward
  digitalWrite(D1, LOW);
  
  digitalWrite(D2, LOW);  // Motor 2 backward
  digitalWrite(D3, HIGH);
  
  Serial.println(F("  ↻ ROTATE RIGHT"));
}

void stopMotors() {
  currentDirection = "none";
  isMoving = false;
  
  // All motors stop
  digitalWrite(D0, LOW);
  digitalWrite(D1, LOW);
  digitalWrite(D2, LOW);
  digitalWrite(D3, LOW);
  
  Serial.println(F("  ⏹ STOP"));
}

void setSpeed(int speed) {
  motorSpeed = constrain(speed, 0, 255);
  Serial.print(F("⚡ Speed: "));
  Serial.println(motorSpeed);
  
  if (motorSpeed > 0 && motorSpeed < 255) {
    Serial.println(F("   Note: Your driver uses fixed speed"));
    Serial.println(F("   Speed setting is for compatibility only"));
  }
}

// ============== GPS FUNCTIONS ==============
void updateGPS() {
  // Read available GPS data
  bool readAnyByte = false;
  while (gpsSerial.available() > 0) {
    char c = gpsSerial.read();
    gpsLastByteTime = millis();
    readAnyByte = true;
    if (gps.encode(c)) {
      // GPS data update complete
      if (gps.location.isValid()) {
        gpsData.latitude = gps.location.lat();
        gpsData.longitude = gps.location.lng();
        gpsData.altitude = gps.altitude.meters();
        gpsData.speed = gps.speed.mps();  // m/s
        gpsData.course = gps.course.deg();
        gpsData.satellites = gps.satellites.value();
        gpsData.hdop = gps.hdop.hdop();
        gpsData.timestamp = gps.date.value() * 1000000 + gps.time.value();
        gpsData.isValid = true;
        gpsData.lastReceivedTime = millis();
        gpsData.dataUpdates++;
        
        // Log new fix every 5 seconds
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
        // No valid location fix - still searching
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

  const unsigned long now = millis();
  if (now - gpsLastHeartbeatTime >= 2000) {
    gpsLastHeartbeatTime = now;
    Serial.print(F("📍 GPS: "));
    if (gpsLastByteTime == 0) {
      Serial.println(F("no UART data yet"));
    } else if (now - gpsLastByteTime > 3000) {
      Serial.print(F("UART silent "));
      Serial.print((now - gpsLastByteTime) / 1000);
      Serial.println(F("s"));
    } else if (gpsData.isValid) {
      Serial.print(F("FIX Lat="));
      Serial.print(gpsData.latitude, 6);
      Serial.print(F(" Lon="));
      Serial.print(gpsData.longitude, 6);
      Serial.print(F(" Sats="));
      Serial.print(gpsData.satellites);
      Serial.print(F(" HDOP="));
      Serial.println(gpsData.hdop, 2);
    } else {
      Serial.print(F("searching Sats="));
      Serial.print(gpsData.satellites);
      Serial.print(F(" age="));
      if (gpsData.lastReceivedTime == 0) {
        Serial.println(F("never"));
      } else {
        Serial.print((now - gpsData.lastReceivedTime) / 1000);
        Serial.println(F("s"));
      }
    }
  }
}

// ============== NPK SENSOR FUNCTIONS ==============
void updateNPKSensor() {
  if (millis() - npkLastUpdate < NPK_UPDATE_INTERVAL_MS) {
    return;
  }
  
  // Clear any existing bytes in buffer
  while(npkSerial.available()) npkSerial.read();

  // Switch RS485 to transmit mode
  digitalWrite(NPK_DE_RE, HIGH);
  delay(10); // Give transceiver time to switch to TX
  
  uint8_t query[8];
  if (currentQueryStep == 0) {
    memcpy(query, queryEnv, sizeof(queryEnv));
  } else {
    memcpy(query, queryNPK, sizeof(queryNPK));
  }
  npkSerial.write(query, 8);
  npkSerial.flush(); // Wait until all bytes are transmitted
  
  // Important timing: wait exactly long enough for the final bit to finish
  delay(3); 
  
  // Switch back to receive mode
  digitalWrite(NPK_DE_RE, LOW);
  
  // Give the bus a moment to settle down before we start reading
  delay(5);
  
  uint8_t frame[64];
  size_t frameLen = 0;
  bool ok = readModbusFrame(frame, sizeof(frame), &frameLen, 500);

  if (ok && frameLen >= 7) {
    if (currentQueryStep == 0 && frame[2] == 0x08 && frameLen >= 13) {
      npkData.moisture = (((uint16_t)frame[3] << 8) | frame[4]) / 10.0;
      npkData.temperature = (((uint16_t)frame[5] << 8) | frame[6]) / 10.0;
      npkData.ec = ((uint16_t)frame[7] << 8) | frame[8];
      npkData.ph = (((uint16_t)frame[9] << 8) | frame[10]) / 10.0;

      currentQueryStep = 1;
      npkLastUpdate = millis() - (NPK_UPDATE_INTERVAL_MS - 400);
      return;
    }

    if (currentQueryStep == 1 && frame[2] == 0x06 && frameLen >= 11) {
      Serial.print(F("🔍 RAW NPK FRAME: "));
      for (size_t i = 0; i < frameLen; i++) {
        Serial.print(frame[i], HEX);
        Serial.print(" ");
      }
      Serial.println();

      npkData.nitrogen = ((uint16_t)frame[3] << 8) | frame[4];
      npkData.phosphorus = ((uint16_t)frame[5] << 8) | frame[6];
      npkData.potassium = ((uint16_t)frame[7] << 8) | frame[8];

      npkData.isValid = true;
      npkData.lastReadTime = millis();
      npkLastUpdate = millis();
      currentQueryStep = 0;

      Serial.print(F("🌱 NPK Data: N=")); Serial.print(npkData.nitrogen, 0);
      Serial.print(F(" P=")); Serial.print(npkData.phosphorus, 0);
      Serial.print(F(" K=")); Serial.print(npkData.potassium, 0);
      Serial.print(F(" | Moist=")); Serial.print(npkData.moisture, 1);
      Serial.print(F("% Temp=")); Serial.print(npkData.temperature, 1);
      Serial.print(F("C EC=")); Serial.print(npkData.ec, 0);
      Serial.print(F(" pH=")); Serial.println(npkData.ph, 1);
      return;
    }
  }

  Serial.println(F("⚠️ NPK Sensor Timeout/CRC/format error."));
  npkData.isValid = false;
  npkLastUpdate = millis();
  currentQueryStep = 0;
}

// ============== SYSTEM FUNCTIONS ==============
void updateSystemStatus() {
  static unsigned long lastUpdate = 0;
  
  if (millis() - lastUpdate > STATUS_UPDATE_INTERVAL) {
    // Update WiFi client count
    wifiClients = WiFi.softAPgetStationNum();
    
    // Auto-stop safety feature
    if (isMoving && (millis() - commandStartTime > COMMAND_TIMEOUT)) {
      Serial.println(F("⚠️ Safety timeout - auto stop"));
      stopMotors();
    }
    
    lastUpdate = millis();
  }
}

void runHeartbeat() {
  static unsigned long lastHeartbeat = 0;
  static bool ledState = false;
  
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    ledState = !ledState;
    digitalWrite(LED_BUILTIN, ledState);
    lastHeartbeat = millis();
  }
}

int readBatteryLevel() {
  // Read battery voltage if ADC pin is connected
  // Returns percentage (0-100)
  
  #ifdef BATTERY_PIN
    int raw = analogRead(BATTERY_PIN);
    // Convert to voltage and calculate percentage
    // This depends on your voltage divider circuit
    float voltage = (raw / 4095.0) * 3.3 * 2; // Example: voltage divider 1:1
    int percent = map(voltage * 100, 300, 420, 0, 100); // 3.0V to 4.2V range
    return constrain(percent, 0, 100);
  #else
    return 100; // Default if not connected
  #endif
}

// ============== SOIL SAMPLING FUNCTIONS ==============
void executeSoilSampling() {
  // State machine for soil sampling
  unsigned long elapsed = millis() - samplingStartTime;
  static int samplingStep = 0;
  static unsigned long stepStartTime = 0;
  
  if (samplingStep == 0) {  // Step 1: Servo1 to 90° (extend arm)
    servo1.write(SAMPLE_ANGLE_MAX);
    Serial.println(F("  Step 1/4: Servo1 → 90° (Arm extended)"));
    samplingStep = 1;
    stepStartTime = millis();
  }
  else if (samplingStep == 1 && millis() - stepStartTime > 3000) {  // Wait 3 seconds
    servo2.write(SAMPLE_ANGLE_MAX);
    Serial.println(F("  Step 2/4: Servo2 → 90° (Bucket extended)"));
    samplingStep = 2;
    stepStartTime = millis();
  }
  else if (samplingStep == 2 && millis() - stepStartTime > 3000) {  // Wait 3 seconds
    servo2.write(SAMPLE_ANGLE_MIN);
    Serial.println(F("  Step 3/4: Servo2 → 0° (Bucket retracted)"));
    samplingStep = 3;
    stepStartTime = millis();
  }
  else if (samplingStep == 3 && millis() - stepStartTime > 3000) {  // Wait 3 seconds
    servo1.write(SAMPLE_ANGLE_MIN);
    Serial.println(F("  Step 4/4: Servo1 → 0° (Arm retracted)"));
    samplingStep = 4;
    stepStartTime = millis();
  }
  else if (samplingStep == 4 && millis() - stepStartTime > 3000) {  // Wait 3 seconds
    Serial.println(F("═════════════════════════"));
    Serial.println(F("✅ SOIL SAMPLING COMPLETE\n"));
    isSampling = false;
    samplingStep = 0;
  }
}

// ============== PATH RECORDING FUNCTIONS ==============
void recordPathWaypoint() {
  // Record waypoint at interval or when distance threshold exceeded
  if (millis() - lastRecordingTime < RECORDING_INTERVAL_MS) {
    return;
  }
  
  // Check if we have space for more waypoints
  if (recordedWaypointCount >= MAX_WAYPOINTS) {
    Serial.println(F("⚠️  Max waypoints reached, stopping recording"));
    isRecording = false;
    return;
  }
  
  // Check minimum distance if not first waypoint
  if (recordedWaypointCount > 0) {
    double distance = calculateDistance(
      gpsData.latitude, gpsData.longitude,
      recordedWaypoints[recordedWaypointCount - 1].latitude,
      recordedWaypoints[recordedWaypointCount - 1].longitude
    );
    
    if (distance < MIN_DISTANCE_METERS && recordedWaypointCount > 1) {
      return;  // Too close to last waypoint, skip this one
    }
  }
  
  // Record waypoint
  recordedWaypoints[recordedWaypointCount].latitude = gpsData.latitude;
  recordedWaypoints[recordedWaypointCount].longitude = gpsData.longitude;
  recordedWaypoints[recordedWaypointCount].altitude = gpsData.altitude;
  recordedWaypoints[recordedWaypointCount].timestamp = millis();
  recordedWaypoints[recordedWaypointCount].index = recordedWaypointCount;
  
  recordedWaypointCount++;
  lastRecordingTime = millis();
  
  // Log progress
  if (recordedWaypointCount % 5 == 0) {
    Serial.print(F("📍 Waypoint #"));
    Serial.print(recordedWaypointCount);
    Serial.print(F(" recorded: "));
    Serial.print(recordedWaypoints[recordedWaypointCount - 1].latitude, 6);
    Serial.print(F(", "));
    Serial.println(recordedWaypoints[recordedWaypointCount - 1].longitude, 6);
  }
}

// ============== AUTONOMOUS NAVIGATION FUNCTIONS ==============
void executeAutonomousNavigation() {
  if (currentWaypointIndex >= activeRoute.waypointCount) {
    // Route complete
    isNavigating = false;
    stopMotors();
    
    Serial.println(F("\n✅ DESTINATION REACHED - ROUTE COMPLETE\n"));
    return;
  }
  
  if (!gpsData.isValid) {
    stopMotors();
    return;  // No GPS fix, can't navigate
  }
  
  Waypoint target = activeRoute.waypoints[currentWaypointIndex];
  
  // Calculate distance to target waypoint
  double distance = calculateDistance(gpsData.latitude, gpsData.longitude, target.latitude, target.longitude);
  double bearing = calculateBearing(gpsData.latitude, gpsData.longitude, target.latitude, target.longitude);
  
  // Check if waypoint reached
  if (distance < navigationTolerance) {
    stopMotors();
    currentWaypointIndex++;
    
    Serial.print(F("✓ Waypoint #"));
    Serial.print(currentWaypointIndex);
    Serial.println(F(" reached"));
    
    delay(500);  // Brief pause before moving to next waypoint
    return;
  }
  
  // Navigate towards target
  navigateTowardsBearing(bearing, distance);
}

void navigateTowardsBearing(double targetBearing, double distance) {
  // Normalize target bearing to 0-360
  while (targetBearing < 0) targetBearing += 360;
  while (targetBearing >= 360) targetBearing -= 360;
  
  // Get current heading from GPS if available
  double currentHeading = gpsData.course;  // 0-360 degrees
  
  // Calculate bearing error
  double bearingError = targetBearing - currentHeading;
  
  // Normalize bearing error to -180 to +180
  if (bearingError > 180) bearingError -= 360;
  if (bearingError < -180) bearingError += 360;
  
  // Navigation control logic
  const double HEADING_TOLERANCE = 15.0;  // degrees
  
  if (fabs(bearingError) > HEADING_TOLERANCE) {
    // Need to turn towards target bearing
    if (bearingError > 0) {
      turnRight();  // Turn right
    } else {
      turnLeft();   // Turn left
    }
  } else {
    // Correct heading, move forward
    forward();
  }
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  // Haversine formula to calculate distance between two GPS points
  const double R = 6371000.0;  // Earth radius in meters
  
  double dLat = (lat2 - lat1) * PI / 180.0;
  double dLon = (lon2 - lon1) * PI / 180.0;
  
  double a = sin(dLat / 2.0) * sin(dLat / 2.0) +
             cos(lat1 * PI / 180.0) * cos(lat2 * PI / 180.0) *
             sin(dLon / 2.0) * sin(dLon / 2.0);
  
  double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
  double distance = R * c;
  
  return distance;
}

double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  // Calculate bearing from point 1 to point 2
  double dLon = (lon2 - lon1) * PI / 180.0;
  lat1 = lat1 * PI / 180.0;
  lat2 = lat2 * PI / 180.0;
  
  double y = sin(dLon) * cos(lat2);
  double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  double bearing = atan2(y, x) * 180.0 / PI;
  
  // Normalize to 0-360
  if (bearing < 0) bearing += 360;
  
  return bearing;
}

// ============== UI FUNCTIONS ==============
void printBootScreen() {
  Serial.println(F("\n\n"));
  Serial.println(F("╔══════════════════════════════════════╗"));
  Serial.println(F("║     ESP32 ROVER CONTROL SYSTEM       ║"));
  Serial.println(F("║            Version 2.0.0             ║"));
  Serial.println(F("╚══════════════════════════════════════╝"));
  Serial.println();
}

void printSystemInfo() {
  Serial.println(F("\n✅ SYSTEM READY"));
  Serial.println(F("═══════════════════════════════════════"));
  Serial.println(F("CONTROL METHODS:"));
  Serial.println(F("  • Bluetooth: ESP32_Rover_BT"));
  Serial.println();
  Serial.println(F("═══════════════════════════════════════\n"));
}

String generateHTML() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>ESP32 Rover Control</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        body {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 16px;
        }
        
        .container {
            max-width: 480px;
            width: 100%;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 32px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
            animation: slideIn 0.3s ease;
        }
        
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 24px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .header p {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .status-panel {
            background: #f8f9fa;
            padding: 20px;
            border-bottom: 1px solid #e9ecef;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 16px;
        }
        
        .status-item {
            background: white;
            padding: 12px;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
        }
        
        .status-label {
            font-size: 12px;
            color: #6c757d;
            margin-bottom: 4px;
        }
        
        .status-value {
            font-size: 18px;
            font-weight: 600;
            color: #343a40;
        }
        
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            color: white;
        }
        
        .badge-moving {
            background: #28a745;
        }
        
        .badge-stopped {
            background: #dc3545;
        }
        
        .control-panel {
            padding: 24px;
        }
        
        .joystick-area {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 24px;
        }
        
        .joystick-row {
            display: flex;
            justify-content: center;
            gap: 12px;
            margin: 6px 0;
        }
        
        .control-btn {
            width: 80px;
            height: 80px;
            border: none;
            border-radius: 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
            transition: transform 0.1s, box-shadow 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
            touch-action: manipulation;
            -webkit-tap-highlight-color: transparent;
        }
        
        .control-btn:active {
            transform: scale(0.95);
            box-shadow: 0 2px 10px rgba(102, 126, 234, 0.6);
        }
        
        .control-btn.stop-btn {
            background: linear-gradient(135deg, #f56565 0%, #c53030 100%);
            width: 120px;
            box-shadow: 0 4px 15px rgba(245, 101, 101, 0.4);
        }
        
        .rotation-area {
            display: flex;
            justify-content: center;
            gap: 16px;
            margin: 24px 0;
        }
        
        .rotation-btn {
            width: 70px;
            height: 70px;
            border: none;
            border-radius: 20px;
            background: linear-gradient(135deg, #9f7aea 0%, #6b46c1 100%);
            color: white;
            font-size: 24px;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(159, 122, 234, 0.4);
            transition: transform 0.1s;
            touch-action: manipulation;
        }
        
        .rotation-btn:active {
            transform: scale(0.95);
        }
        
        .speed-control {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 16px;
            margin-top: 24px;
        }
        
        .speed-label {
            display: flex;
            justify-content: space-between;
            margin-bottom: 12px;
            color: #495057;
            font-weight: 500;
        }
        
        .speed-slider {
            width: 100%;
            height: 8px;
            border-radius: 4px;
            background: linear-gradient(90deg, #48bb78 0%, #f6ad55 50%, #f56565 100%);
            -webkit-appearance: none;
            appearance: none;
        }
        
        .speed-slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            background: white;
            border: 2px solid #667eea;
            cursor: pointer;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
        }
        
        .connection-info {
            background: #f8f9fa;
            padding: 16px;
            border-radius: 12px;
            margin: 16px 0;
            text-align: center;
            font-size: 14px;
            color: #6c757d;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 16px;
            text-align: center;
            font-size: 12px;
            color: #6c757d;
            border-top: 1px solid #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 ROVER CONTROL</h1>
            <p>ESP32 Rover Control System</p>
        </div>
        
        <div class="status-panel">
            <div class="status-grid">
                <div class="status-item">
                    <div class="status-label">Status</div>
                    <div class="status-value">
                        <span id="statusBadge" class="status-badge badge-stopped">STOPPED</span>
                    </div>
                </div>
                <div class="status-item">
                    <div class="status-label">Direction</div>
                    <div class="status-value" id="directionDisplay">none</div>
                </div>
                <div class="status-item">
                    <div class="status-label">Speed</div>
                    <div class="status-value" id="speedDisplay">255</div>
                </div>
                <div class="status-item">
                    <div class="status-label">Battery</div>
                    <div class="status-value" id="batteryDisplay">100%</div>
                </div>
            </div>
        </div>
        
        <div class="control-panel">
            <div class="joystick-area">
                <div class="joystick-row">
                    <button class="control-btn" onmousedown="sendCommand('forward')" ontouchstart="sendCommand('forward')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">▲</button>
                </div>
                <div class="joystick-row">
                    <button class="control-btn" onmousedown="sendCommand('left')" ontouchstart="sendCommand('left')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">◀</button>
                    <button class="control-btn stop-btn" onmousedown="sendCommand('stop')" ontouchstart="sendCommand('stop')">⏹</button>
                    <button class="control-btn" onmousedown="sendCommand('right')" ontouchstart="sendCommand('right')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">▶</button>
                </div>
                <div class="joystick-row">
                    <button class="control-btn" onmousedown="sendCommand('backward')" ontouchstart="sendCommand('backward')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">▼</button>
                </div>
            </div>
            
            <div class="rotation-area">
                <button class="rotation-btn" onmousedown="sendCommand('rotate-left')" ontouchstart="sendCommand('rotate-left')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">↺</button>
                <button class="rotation-btn" onmousedown="sendCommand('rotate-right')" ontouchstart="sendCommand('rotate-right')" onmouseup="sendCommand('stop')" ontouchend="sendCommand('stop')">↻</button>
            </div>
            
            <div class="speed-control">
                <div class="speed-label">
                    <span>Speed Control</span>
                    <span id="speedValue">255</span>
                </div>
                <input type="range" min="0" max="255" value="255" class="speed-slider" id="speedSlider" oninput="updateSpeed(this.value)">
            </div>
            
            <div class="connection-info" id="connectionInfo">
                <span id="connectionStatus">● Connected</span> | 
                <span id="clientCount">0 clients</span>
            </div>
        </div>
        
        <div class="footer">
            ESP32 Rover Control v2.0 | Use for educational purposes
        </div>
    </div>
    
    <script>
        // API Base URL
        const API_BASE = window.location.origin;
        
        // Send command function
        function sendCommand(cmd) {
            fetch(`${API_BASE}/${cmd}`)
                .then(response => response.json())
                .then(data => {
                    console.log('Command sent:', cmd);
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        }
        
        // Update speed function
        function updateSpeed(value) {
            document.getElementById('speedValue').innerText = value;
            fetch(`${API_BASE}/api/speed?value=${value}`)
                .then(response => response.json())
                .then(data => {
                    console.log('Speed updated:', value);
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        }
        
        // Update status function
        function updateStatus() {
            fetch(`${API_BASE}/api/status`)
                .then(response => response.json())
                .then(data => {
                    // Update direction
                    document.getElementById('directionDisplay').innerText = data.direction || 'none';
                    
                    // Update speed
                    document.getElementById('speedDisplay').innerText = data.speed;
                    document.getElementById('speedValue').innerText = data.speed;
                    document.getElementById('speedSlider').value = data.speed;
                    
                    // Update battery
                    document.getElementById('batteryDisplay').innerText = data.battery + '%';
                    
                    // Update status badge
                    const badge = document.getElementById('statusBadge');
                    if (data.isMoving) {
                        badge.innerText = 'MOVING';
                        badge.className = 'status-badge badge-moving';
                    } else {
                        badge.innerText = 'STOPPED';
                        badge.className = 'status-badge badge-stopped';
                    }
                    
                    // Update connection info
                    document.getElementById('clientCount').innerText = data.clients + ' clients';
                })
                .catch(error => {
                    console.error('Status error:', error);
                    document.getElementById('connectionStatus').innerHTML = '● Disconnected';
                });
        }
        
        // Update status every 500ms
        setInterval(updateStatus, 500);
        
        // Prevent context menu on buttons
        document.querySelectorAll('button').forEach(button => {
            button.addEventListener('contextmenu', e => e.preventDefault());
        });
    </script>
</body>
</html>
)rawliteral";
  
  return html;
}