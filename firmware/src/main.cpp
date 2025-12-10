#include <Arduino.h>
#include <NimBLEDevice.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// BLE GATT UUIDs - Must match Flutter app
#define SERVICE_UUID        "0000feed-0000-1000-8000-00805f9b34fb"
#define WRITE_CHAR_UUID     "0000beef-0000-1000-8000-00805f9b34fb"
#define NOTIFY_CHAR_UUID    "0000cafe-0000-1000-8000-00805f9b34fb"

// Device configuration
#define DEVICE_NAME         "Energy-Monitor-001"
#define FW_VERSION          "1.0.0"

// Firebase configuration (to be set after provisioning)
String firebaseProjectId = "";
String firebaseApiKey = "";
String userId = "";
String deviceId = "";

// WiFi credentials (received via BLE)
String wifiSSID = "";
String wifiPassword = "";
String timezone = "Asia/Colombo";
String deviceName = DEVICE_NAME;

// BLE objects
NimBLEServer* pServer = nullptr;
NimBLECharacteristic* pWriteCharacteristic = nullptr;
NimBLECharacteristic* pNotifyCharacteristic = nullptr;
bool deviceConnected = false;
bool wifiProvisioned = false;

// Sensor simulation variables (replace with actual sensor reads)
float currentPower = 0.0;
float currentVoltage = 230.0;
float currentCurrent = 0.0;
float cumulativeEnergy = 0.0;
unsigned long lastReadingTime = 0;
const unsigned long READING_INTERVAL = 5000; // 5 seconds

// BLE Server Callbacks
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Device connected");
    }

    void onDisconnect(NimBLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Device disconnected");
        // Restart advertising
        NimBLEDevice::startAdvertising();
    }
};

// BLE Characteristic Callbacks
class ProvisioningCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
            Serial.println("Received provisioning data:");
            Serial.println(value.c_str());
            
            // Parse JSON
            StaticJsonDocument<512> doc;
            DeserializationError error = deserializeJson(doc, value.c_str());
            
            if (error) {
                Serial.print("JSON parse error: ");
                Serial.println(error.c_str());
                sendStatus("err", "invalid-json");
                return;
            }
            
            // Extract credentials
            if (doc.containsKey("ssid") && doc.containsKey("pass")) {
                wifiSSID = doc["ssid"].as<String>();
                wifiPassword = doc["pass"].as<String>();
                
                if (doc.containsKey("tz")) {
                    timezone = doc["tz"].as<String>();
                }
                if (doc.containsKey("deviceName")) {
                    deviceName = doc["deviceName"].as<String>();
                }
                
                Serial.println("Credentials received, attempting to connect...");
                sendStatus("ok", "connecting");
                
                // Attempt WiFi connection
                if (connectWiFi()) {
                    wifiProvisioned = true;
                    sendStatus("ok", "connected");
                    Serial.println("WiFi connected successfully!");
                } else {
                    sendStatus("err", "bad-credentials");
                    Serial.println("WiFi connection failed");
                }
            } else {
                sendStatus("err", "missing-fields");
            }
        }
    }
    
    void sendStatus(const char* status, const char* msg) {
        if (pNotifyCharacteristic != nullptr) {
            StaticJsonDocument<128> doc;
            doc["status"] = status;
            doc["msg"] = msg;
            
            String output;
            serializeJson(doc, output);
            
            pNotifyCharacteristic->setValue(output.c_str());
            pNotifyCharacteristic->notify();
            
            Serial.print("Status sent: ");
            Serial.println(output);
        }
    }
    
    bool connectWiFi() {
        WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
        
        int attempts = 0;
        while (WiFi.status() != WL_CONNECTED && attempts < 20) {
            delay(500);
            Serial.print(".");
            attempts++;
        }
        Serial.println();
        
        if (WiFi.status() == WL_CONNECTED) {
            Serial.print("Connected to WiFi. IP: ");
            Serial.println(WiFi.localIP());
            return true;
        }
        
        return false;
    }
};

void setupBLE() {
    Serial.println("Initializing BLE...");
    
    // Initialize NimBLE
    NimBLEDevice::init(deviceName.c_str());
    
    // Create BLE Server
    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    
    // Create BLE Service
    NimBLEService* pService = pServer->createService(SERVICE_UUID);
    
    // Create Provisioning Write Characteristic
    pWriteCharacteristic = pService->createCharacteristic(
        WRITE_CHAR_UUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
    );
    pWriteCharacteristic->setCallbacks(new ProvisioningCallbacks());
    
    // Create Status Notify Characteristic
    pNotifyCharacteristic = pService->createCharacteristic(
        NOTIFY_CHAR_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );
    
    // Start service
    pService->start();
    
    // Start advertising
    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->start();
    
    Serial.println("BLE advertising started");
    Serial.print("Device name: ");
    Serial.println(deviceName);
}

void readSensors() {
    // Simulate sensor readings (replace with actual sensor code)
    // For demo: generate realistic-looking values
    currentVoltage = 230.0 + random(-5, 5);
    currentPower = 200.0 + random(-50, 150);
    currentCurrent = currentPower / currentVoltage;
    
    // Calculate energy delta (Wh)
    unsigned long now = millis();
    if (lastReadingTime > 0) {
        float hours = (now - lastReadingTime) / 3600000.0;
        cumulativeEnergy += currentPower * hours;
    }
    lastReadingTime = now;
    
    Serial.printf("Power: %.1fW, Voltage: %.1fV, Current: %.2fA, Energy: %.2fWh\n",
                  currentPower, currentVoltage, currentCurrent, cumulativeEnergy);
}

void uploadToFirestore() {
    if (!wifiProvisioned || WiFi.status() != WL_CONNECTED) {
        return;
    }
    
    // NOTE: This is a simplified example
    // In production, use Firebase REST API with proper authentication
    // or use ESP32 Firebase library with device tokens
    
    Serial.println("Uploading to Firestore...");
    
    HTTPClient http;
    
    // Construct Firestore REST API endpoint
    // Format: https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/{collection}/{doc}
    String url = "https://firestore.googleapis.com/v1/projects/" + firebaseProjectId + 
                 "/databases/(default)/documents/users/" + userId + 
                 "/devices/" + deviceId + "/readings";
    
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    
    // Create reading document
    StaticJsonDocument<512> doc;
    doc["fields"]["ts"]["timestampValue"] = "2023-01-01T00:00:00Z"; // Use proper timestamp
    doc["fields"]["power_w"]["doubleValue"] = currentPower;
    doc["fields"]["voltage_v"]["doubleValue"] = currentVoltage;
    doc["fields"]["current_a"]["doubleValue"] = currentCurrent;
    doc["fields"]["energy_wh"]["doubleValue"] = cumulativeEnergy;
    doc["fields"]["sample_ms"]["integerValue"] = String(millis());
    
    String jsonOutput;
    serializeJson(doc, jsonOutput);
    
    int httpResponseCode = http.POST(jsonOutput);
    
    if (httpResponseCode > 0) {
        Serial.print("Upload success: ");
        Serial.println(httpResponseCode);
    } else {
        Serial.print("Upload error: ");
        Serial.println(httpResponseCode);
    }
    
    http.end();
}

void setup() {
    Serial.begin(115200);
    Serial.println("Energy Monitor starting...");
    
    // Setup BLE for provisioning
    setupBLE();
    
    Serial.println("Waiting for provisioning...");
}

void loop() {
    // Read sensors periodically
    if (millis() - lastReadingTime >= READING_INTERVAL) {
        readSensors();
        
        // Upload to Firestore if provisioned
        if (wifiProvisioned) {
            uploadToFirestore();
        }
    }
    
    delay(100);
}
