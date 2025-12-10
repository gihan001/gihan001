# Architecture Overview - Energy Monitor System

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Presentation Layer (UI)                    │ │
│  │  - Screens (Auth, DeviceList, Dashboard, BLE Scan)    │ │
│  │  - Widgets (Charts, Cards, Lists)                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↕                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         State Management (Riverpod)                     │ │
│  │  - Providers (auth, devices, readings, BLE)           │ │
│  │  - State (selected device, scan results)              │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↕                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Data Layer                                 │ │
│  │  ┌──────────────────┐    ┌──────────────────┐        │ │
│  │  │ Firebase Repo    │    │ BLE Service      │        │ │
│  │  │ - Auth           │    │ - Scan           │        │ │
│  │  │ - Devices CRUD   │    │ - Connect        │        │ │
│  │  │ - Readings       │    │ - Provision      │        │ │
│  │  └──────────────────┘    └──────────────────┘        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    ↕                        ↕
            (HTTPS/WSS)               (BLE GATT)
                    ↕                        ↕
     ┌──────────────────────────┐   ┌──────────────────┐
     │   Firebase Backend       │   │   ESP32 Device   │
     │   - Firestore DB         │   │   - BLE Server   │
     │   - Auth Service         │   │   - WiFi Client  │
     │   - Analytics            │   │   - Sensors      │
     │   - Crashlytics          │   │   - HTTP Client  │
     └──────────────────────────┘   └──────────────────┘
                                              ↓
                                         (HTTPS)
                                              ↓
                                    ┌──────────────────┐
                                    │   Firestore DB   │
                                    │   /users/        │
                                    │     /devices/    │
                                    │       /readings/ │
                                    └──────────────────┘
```

## Component Details

### Flutter App Architecture

#### 1. Presentation Layer
**Location:** `lib/src/ui/`

**Responsibilities:**
- Render UI components
- Handle user interactions
- Display data from providers
- Navigate between screens

**Key Components:**
- `auth_screen.dart`: Anonymous authentication UI
- `device_list_screen.dart`: List of user's devices
- `ble_scan_screen.dart`: BLE device scanner with RSSI
- `provisioning_screen.dart`: WiFi credential entry form
- `device_dashboard_screen.dart`: Live charts and metrics

**Design Patterns:**
- Material Design 3
- Responsive layouts
- Dark mode support
- Accessibility labels

#### 2. State Management Layer
**Location:** `lib/src/features/providers.dart`

**Technology:** Riverpod 2.x

**Providers:**
```dart
// Core Services
loggerProvider           -> Logger instance
firebaseRepositoryProvider -> Firebase operations
bleProvisioningServiceProvider -> BLE operations

// Authentication
authStateProvider        -> Stream<User?> from Firebase Auth

// Data Streams
userDevicesProvider      -> Stream<List<Device>> per user
deviceReadingsProvider   -> Stream<List<Reading>> per device (family)

// State
selectedDeviceIdProvider -> Currently selected device
bleScanResultsProvider   -> BLE scan results stream
```

**Benefits:**
- Automatic caching
- Lifecycle management
- Easy testing with overrides
- Type-safe

#### 3. Data Layer
**Location:** `lib/src/data/`

##### Firebase Repository (`firebase/firebase_repository.dart`)

**Responsibilities:**
- Abstract Firestore operations
- Handle authentication
- Manage document CRUD
- Stream real-time updates

**Key Methods:**
```dart
// Auth
signInAnonymously() -> Future<UserCredential>
authStateChanges() -> Stream<User?>

// Devices
registerDevice(Device) -> Future<void>
watchUserDevices() -> Stream<List<Device>>
getDevice(String) -> Future<Device?>

// Readings
watchDeviceReadings(String) -> Stream<List<Reading>>
getReadingsInRange(String, DateTime, DateTime) -> Future<List<Reading>>
```

**Error Handling:**
- Throws exceptions for auth errors
- Returns empty streams for unauthenticated users
- Logs errors with Logger

##### BLE Provisioning Service (`ble/ble_provisioning_service.dart`)

**Responsibilities:**
- Scan for BLE devices
- Connect to devices
- Discover GATT services
- Send provisioning data
- Receive status notifications

**Key Methods:**
```dart
scanForDevices() -> Stream<ScanResult>
connectToDevice(BluetoothDevice) -> Future<void>
provisionDevice(ProvisioningData) -> Future<void>
provisionDeviceSecure(ProvisioningData, String) -> Future<void>
waitForProvisioningResult() -> Future<Map<String, dynamic>>
disconnect() -> Future<void>
```

**State Machine:**
```
IDLE -> SCANNING -> CONNECTING -> CONNECTED -> PROVISIONING -> SUCCESS/ERROR
```

#### 4. Domain Layer
**Location:** `lib/src/domain/`

**Models:**
- `Device`: Device metadata
- `Reading`: Energy reading data point
- `ProvisioningData`: WiFi credentials payload

**Technologies:**
- `freezed`: Immutable data classes
- `json_serializable`: JSON serialization

### ESP32 Firmware Architecture

#### Components

1. **BLE Server**
   - Advertises service UUID
   - Handles characteristic reads/writes
   - Sends notifications
   - Manages connections

2. **Provisioning Handler**
   - Receives credentials via BLE
   - Validates JSON format
   - Triggers WiFi connection
   - Sends status notifications

3. **WiFi Client**
   - Connects to AP with credentials
   - Maintains connection
   - Handles reconnection

4. **Sensor Interface**
   - Reads power/voltage/current (simulated)
   - Calculates energy deltas
   - Maintains cumulative totals

5. **Firestore Client**
   - HTTP POST to Firestore REST API
   - Authenticates with device token
   - Uploads reading documents

#### Initialization Flow

```
1. setup()
   ├─ Serial.begin(115200)
   ├─ setupBLE()
   │  ├─ NimBLEDevice::init()
   │  ├─ Create server & service
   │  ├─ Create characteristics
   │  └─ Start advertising
   └─ Wait for provisioning

2. loop()
   ├─ Check provisioning status
   ├─ If provisioned:
   │  ├─ readSensors()
   │  └─ uploadToFirestore()
   └─ delay(100ms)
```

### Firebase Backend Architecture

#### Firestore Data Model

```
/users (collection)
  /{userId} (document)
    /devices (subcollection)
      /{deviceId} (document)
        - deviceName: string
        - model: string
        - registeredAt: timestamp
        - lastSeen: timestamp
        - fwVersion: string
        - owner: userId
        
        /readings (subcollection)
          /{readingId} (document)
            - ts: timestamp
            - power_w: number
            - voltage_v: number
            - current_a: number
            - energy_wh: number
            - sample_ms: integer
```

#### Security Rules

**Principle:** User isolation + write-once readings

```javascript
// Devices: user can read/write own devices
allow read, write: if request.auth.uid == userId

// Readings: 
// - User can read own
// - User/admin can create
// - No updates/deletes (immutable)
allow read: if request.auth.uid == userId
allow create: if authenticated and (isOwner or isAdmin)
allow update, delete: if false
```

#### Indexes

**Required:**
- `(deviceId, ts DESC)` for efficient time-series queries
- `(ts)` for global time-based filtering

### Communication Protocols

#### BLE GATT Protocol

**Service:** `0000feed-0000-1000-8000-00805f9b34fb`

**Characteristics:**

1. **Provisioning Write** (Write)
   - UUID: `0000beef-0000-1000-8000-00805f9b34fb`
   - Properties: WRITE, WRITE_NO_RESPONSE
   - Format: JSON UTF-8
   - Max size: Depends on MTU (default 23 bytes, negotiable up to 517)
   - Chunking: Required for payloads > MTU-3

2. **Status Notify** (Notify)
   - UUID: `0000cafe-0000-1000-8000-00805f9b34fb`
   - Properties: NOTIFY
   - Format: JSON UTF-8
   - Example: `{"status":"ok","msg":"connected"}`

**Message Flow:**
```
App                         Device
 |                             |
 |--- Connect ----------------->|
 |<-- Connected ----------------|
 |--- Subscribe to Notify ----->|
 |<-- Subscribed ---------------|
 |--- Write Credentials ------->|
 |                             | (Attempt WiFi)
 |<-- Notify: connecting -------|
 |<-- Notify: connected --------|
 |--- Disconnect --------------->|
```

#### Firestore Protocol

**Technology:** WebSocket (for streams) + HTTPS (for writes)

**Operations:**
- `snapshots()`: Real-time stream of document changes
- `set()`: Write/overwrite document
- `add()`: Create document with auto-generated ID
- `update()`: Partial update of document

**Authentication:**
- ID tokens from Firebase Auth
- Automatically refreshed by SDK
- Verified by Firestore security rules

## Data Flow Examples

### 1. Device Provisioning Flow

```
1. User taps "Add Device"
2. App navigates to BLE Scan screen
3. App requests BLE permissions
4. App starts BLE scan (scanForDevices)
5. Device advertises service UUID
6. App displays device in list
7. User selects device
8. App navigates to Provisioning screen
9. App prefills WiFi SSID (from connectivity_plus)
10. User enters password and device name
11. User taps "Provision"
12. App connects to device (connectToDevice)
13. App discovers GATT services & characteristics
14. App subscribes to Status Notify characteristic
15. App sends credentials (provisionDevice)
16. Device receives credentials
17. Device attempts WiFi connection
18. Device sends status notification ("connecting")
19. Device sends status notification ("connected" or "error")
20. App receives notification
21. If success:
    a. App registers device in Firestore
    b. App navigates back to device list
    c. Device appears in list
22. If error:
    a. App shows error message
    b. User can retry
```

### 2. Real-time Dashboard Flow

```
1. User taps device in list
2. App navigates to Dashboard screen
3. Dashboard subscribes to readings stream:
   deviceReadingsProvider(deviceId)
4. Provider calls repository.watchDeviceReadings(deviceId)
5. Repository creates Firestore snapshot listener
6. Firestore streams existing readings (latest 100)
7. Dashboard receives readings
8. Dashboard processes data for charts
9. Dashboard renders:
   - Current stats cards
   - Power chart
   - Voltage chart
   - Recent readings list
10. Device uploads new reading to Firestore
11. Firestore pushes update to app
12. Provider emits new state
13. Dashboard automatically rebuilds
14. Charts animate with new data point
```

### 3. Fake Device Simulation Flow

```
1. User runs: python fake_device.py --credentials ... --user-id ...
2. Script initializes Firebase Admin SDK
3. Script registers device document in Firestore
4. Script enters main loop:
   a. Calculate time-based usage pattern (peak/off-peak)
   b. Generate random power variation
   c. Calculate voltage, current, energy
   d. Create reading document
   e. Write to Firestore (readings.add)
   f. Update device lastSeen
   g. Log to console
   h. Sleep for interval
5. App receives reading via Firestore stream
6. Loop continues until Ctrl+C
```

## Testing Strategy

### Unit Tests
- **Target:** Individual functions and classes
- **Tools:** flutter_test, mocktail
- **Coverage:** Domain models, repository methods, BLE service logic
- **Mocking:** Firebase, BLE platform channels

### Widget Tests
- **Target:** UI components in isolation
- **Tools:** flutter_test, WidgetTester
- **Coverage:** Screens, widgets, navigation
- **Mocking:** Providers with overrides

### Integration Tests
- **Target:** Full user flows
- **Tools:** integration_test package
- **Coverage:** Provisioning flow, dashboard display
- **Environment:** Emulator with Firebase emulator suite

### E2E Tests
- **Target:** Real devices + Firebase
- **Tools:** integration_test + physical device
- **Coverage:** BLE provisioning, real-time updates
- **Environment:** Test Firebase project

## Deployment Architecture

### Development
```
Developer Machine
  ├─ Flutter App (flutter run)
  ├─ Fake Device (python script)
  └─ Firebase (test project)
```

### Staging
```
GitHub Actions
  ├─ Lint + Test
  ├─ Build APK/IPA
  └─ Upload artifacts

Firebase (staging project)
  ├─ Firestore (test data)
  ├─ Auth (anonymous)
  └─ Crashlytics (staging logs)
```

### Production
```
Play Store / App Store
  ├─ Signed APK/IPA
  └─ Release notes

Firebase (production project)
  ├─ Firestore (with backups)
  ├─ Auth (with quotas)
  ├─ Crashlytics (monitoring)
  └─ Analytics (usage tracking)

ESP32 Devices
  ├─ Signed firmware
  └─ OTA updates
```

## Security Architecture

### Defense in Depth

1. **Transport Layer**
   - BLE: Secure Connections (LE SC)
   - HTTPS: TLS 1.2+ for Firestore
   - WiFi: WPA2/WPA3

2. **Application Layer**
   - Option A: ECDH + AES-GCM for provisioning
   - Firebase Auth tokens for API calls
   - Firestore security rules for authorization

3. **Data Layer**
   - At-rest encryption in Firestore
   - Secure storage for device keys (NVS encryption)
   - No plaintext credentials in logs

4. **Device Layer**
   - Signed firmware (OTA)
   - Secure boot (production)
   - Hardware RNG for keys

## Performance Considerations

### Flutter App
- **State:** Riverpod caches and deduplicates streams
- **UI:** Charts limited to 50 data points for smooth rendering
- **Network:** Firestore uses efficient binary protocol + compression
- **Memory:** Streams automatically cancel when not watched

### ESP32
- **Memory:** ~320KB RAM, ~4MB Flash
- **CPU:** Dual-core 240MHz (ample for this workload)
- **Power:** ~80mA active, ~10μA deep sleep
- **Network:** 5s reading interval to conserve power and bandwidth

### Firestore
- **Reads:** 50K free per day, then $0.06 per 100K
- **Writes:** 20K free per day, then $0.18 per 100K
- **Storage:** 1GB free, then $0.18 per GB
- **Estimated:** 10 devices × 17K readings/day = $2-3/month

## Scalability

### Current Limits
- **Devices per user:** 100 (Firestore subcollection limit: millions)
- **Readings per device:** Unlimited (time-series appropriate)
- **Concurrent users:** 100K+ (Firebase scales automatically)

### Optimization Strategies
- **Aggregation:** Use Cloud Functions to roll up hourly/daily stats
- **Archival:** Move old readings to Cloud Storage
- **Caching:** Cache dashboard data in app for offline viewing
- **Batching:** Batch writes on device side (send 10 readings at once)

## Observability

### Logging
- **Flutter:** Logger package with levels (debug, info, warn, error)
- **ESP32:** Serial output with timestamps
- **Firebase:** Cloud Logging (auto-enabled)

### Monitoring
- **Crashlytics:** Automatic crash reporting with stack traces
- **Analytics:** Custom events (provisioning_attempt, etc.)
- **Firestore:** Built-in metrics (reads, writes, latency)

### Alerting
- **Firebase Alerts:** Email on quota exceeded
- **Crashlytics:** Email on new crash
- **Custom:** Cloud Functions for anomaly detection

---

This architecture provides:
- ✅ Separation of concerns
- ✅ Testability
- ✅ Scalability
- ✅ Security
- ✅ Observability
- ✅ Maintainability
