# Energy Monitor System

A production-grade, end-to-end energy monitoring system with Flutter mobile app, ESP32 firmware, and Firebase backend.

## 🚀 Quick Start

This repository contains a complete energy monitoring solution with:
- **Flutter Mobile App**: BLE provisioning, real-time dashboard, historical charts
- **ESP32 Firmware**: BLE server, WiFi connectivity, Firestore integration
- **Firebase Backend**: Firestore database, authentication, security rules
- **Dev Tools**: Fake device simulator for testing without hardware
- **CI/CD**: GitHub Actions workflow for automated testing and builds

## 📁 Repository Structure

```
/energy-monitor-app
├── flutter_app/          # Flutter mobile application
│   ├── lib/
│   │   ├── src/
│   │   │   ├── ui/              # UI screens and widgets
│   │   │   ├── features/        # Riverpod providers
│   │   │   ├── data/            # Data layer
│   │   │   │   ├── firebase/    # Firebase repository
│   │   │   │   └── ble/         # BLE provisioning service
│   │   │   └── domain/          # Domain models
│   │   └── main.dart
│   ├── test/                    # Unit tests
│   ├── integration_test/        # Integration tests
│   └── pubspec.yaml
├── firmware/             # ESP32 firmware (PlatformIO)
│   ├── platformio.ini
│   └── src/
│       └── main.cpp
├── dev-tools/            # Development utilities
│   ├── fake_device.py           # Fake device simulator
│   ├── requirements.txt
│   └── firestore_rules.json     # Firestore security rules
└── .github/
    └── workflows/
        └── ci.yml                # CI/CD pipeline
```

## 🔧 Prerequisites

### For Flutter App Development
- Flutter SDK >= 3.0.0 ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Dart >= 3.0.0
- Android Studio or VS Code
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)

### For ESP32 Firmware Development
- PlatformIO ([Install PlatformIO](https://platformio.org/install))
- ESP32 development board

### For Dev Tools
- Python 3.10+
- Firebase service account credentials

## 🏗️ Setup Instructions

### 1. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **Authentication** (Anonymous sign-in)
3. Enable **Cloud Firestore**
4. Download configuration files:
   - For Android: `google-services.json` → place in `flutter_app/android/app/`
   - For iOS: `GoogleService-Info.plist` → place in `flutter_app/ios/Runner/`
5. Deploy Firestore security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
   Use the rules from `dev-tools/firestore_rules.json`

6. Create required Firestore indexes:
   - Collection: `users/{userId}/devices/{deviceId}/readings`
   - Fields: `ts` (Descending)

### 2. Flutter App Setup

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run code generation (for freezed and json_serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

#### Build Release APK
```bash
cd flutter_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Build Debug APK
```bash
cd flutter_app
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### 3. ESP32 Firmware Setup

```bash
cd firmware

# Install dependencies
platformio lib install

# Build firmware
platformio run -e esp32dev

# Upload to ESP32 (connect via USB)
platformio run -e esp32dev -t upload

# Monitor serial output
platformio device monitor -b 115200
```

**Configuration Required:**
Edit `firmware/src/main.cpp` and set:
- `firebaseProjectId`: Your Firebase project ID
- `firebaseApiKey`: Your Firebase Web API key
- `userId`: A valid user ID from Firebase Auth
- `deviceId`: Unique identifier for the device

### 4. Dev Tools Setup (Fake Device)

The fake device simulator allows testing the Flutter app without physical hardware.

```bash
cd dev-tools

# Install dependencies
pip install -r requirements.txt

# Download Firebase service account key
# 1. Go to Firebase Console → Project Settings → Service Accounts
# 2. Generate new private key → save as service-account.json

# Run fake device
python fake_device.py \
  --credentials service-account.json \
  --user-id YOUR_USER_ID \
  --device-id fake-device-001 \
  --device-name "Fake Energy Monitor" \
  --interval 5
```

**Arguments:**
- `--credentials`: Path to Firebase service account JSON
- `--user-id`: Firebase user ID (get from Firebase Console after sign-in)
- `--device-id`: Unique device identifier
- `--device-name`: Display name for the device
- `--interval`: Seconds between readings (default: 5)
- `--count`: Number of readings (omit for infinite)

## 🧪 Testing

### Unit Tests
```bash
cd flutter_app
flutter test
```

### Integration Tests
```bash
cd flutter_app
flutter test integration_test
```

### Run with Coverage
```bash
cd flutter_app
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🔐 Security

### Current Implementation (Option B - Basic)
- Uses BLE Secure Connections with link-layer encryption
- WiFi credentials transmitted over encrypted BLE link
- **Status**: Acceptable for development, NOT recommended for production

### Recommended Production Implementation (Option A - Secure)

**Migration Path:**

1. **Device Side (ESP32):**
   - Generate Curve25519 key pair at first boot
   - Store private key securely
   - Advertise public key in BLE advertisement or separate characteristic
   
2. **App Side (Flutter):**
   - Retrieve device public key
   - Generate ephemeral ECDH key pair
   - Perform ECDH to derive shared secret
   - Use AES-GCM to encrypt provisioning payload
   - Send encrypted data to device

3. **Libraries to Use:**
   - Flutter: `cryptography` package
   - ESP32: `mbedtls` library (included in ESP-IDF)

**Example encryption flow:**
```dart
// Flutter app
import 'package:cryptography/cryptography.dart';

Future<void> provisionDeviceSecure(String devicePubKey, ProvisioningData data) async {
  final algorithm = X25519();
  final ephemeralKeyPair = await algorithm.newKeyPair();
  
  // Perform ECDH
  final sharedSecret = await algorithm.sharedSecretKey(
    keyPair: ephemeralKeyPair,
    remotePublicKey: SimplePublicKey(base64Decode(devicePubKey), type: KeyPairType.x25519),
  );
  
  // Encrypt with AES-GCM
  final cipher = AesGcm.with256bits();
  final secretBox = await cipher.encrypt(
    utf8.encode(jsonEncode(data.toJson())),
    secretKey: sharedSecret,
  );
  
  // Send: ephemeralPublicKey + nonce + ciphertext + mac
}
```

### Additional Security Recommendations

1. **Rate Limiting**: Limit provisioning attempts to prevent brute-force
2. **Device Identity**: Store device keypairs at manufacturing or first boot
3. **Provisioning Tokens**: Use Firebase Cloud Functions to issue ephemeral tokens
4. **OTA Updates**: Implement signed firmware updates
5. **Secrets Management**: Never commit API keys or credentials to source control

## 📊 Firestore Schema

### Device Document
```
/users/{userId}/devices/{deviceId}
  - deviceName: string
  - model: string
  - registeredAt: timestamp
  - lastSeen: timestamp
  - fwVersion: string
  - owner: userId
```

### Reading Document
```
/users/{userId}/devices/{deviceId}/readings/{readingId}
  - ts: timestamp
  - power_w: number
  - voltage_v: number
  - current_a: number
  - energy_wh: number (cumulative)
  - sample_ms: integer
```

### Required Indexes
- Compound index on `(deviceId, ts DESC)` in readings collection

## 🔌 BLE GATT Contract

### Service UUID
`0000feed-0000-1000-8000-00805f9b34fb`

### Characteristics

1. **Provisioning Write** (Write without response)
   - UUID: `0000beef-0000-1000-8000-00805f9b34fb`
   - Payload: JSON string with WiFi credentials
   ```json
   {
     "ssid": "WiFi_Name",
     "pass": "password",
     "tz": "Asia/Colombo",
     "deviceName": "Energy-Monitor-001",
     "protoVersion": "1.0"
   }
   ```

2. **Status Notify** (Notify)
   - UUID: `0000cafe-0000-1000-8000-00805f9b34fb`
   - Notifications: JSON status messages
   ```json
   {"status": "ok", "msg": "connected"}
   {"status": "err", "msg": "bad-credentials"}
   ```

## 🎯 Features

### Implemented
- ✅ Anonymous authentication
- ✅ BLE device scanning
- ✅ BLE provisioning (Option B - Basic)
- ✅ Real-time data streaming from Firestore
- ✅ Live power/voltage/current charts
- ✅ Device registration and management
- ✅ Dark mode support
- ✅ Fake device simulator for testing
- ✅ CI/CD pipeline
- ✅ Unit and integration tests
- ✅ Crashlytics and Analytics integration

### TODO / Future Enhancements
- ⬜ Secure provisioning (Option A with encryption)
- ⬜ Multi-language support (add Sinhala, etc.)
- ⬜ OTA firmware updates
- ⬜ Export data to CSV
- ⬜ Energy usage predictions
- ⬜ Billing estimates
- ⬜ Push notifications for anomalies
- ⬜ Multi-device aggregation dashboard
- ⬜ Cloud Functions for data aggregation

## 🐛 Troubleshooting

### Flutter Build Issues

**Issue**: `MissingPluginException`
```bash
flutter clean
flutter pub get
flutter run
```

**Issue**: Generated files not found (`.g.dart`, `.freezed.dart`)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### BLE Issues

**Issue**: BLE not working on Android
- Ensure permissions in `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  ```

**Issue**: Cannot find devices
- Check ESP32 is powered and running
- Verify service UUID matches in both app and firmware
- Check Bluetooth is enabled on phone

### Firebase Issues

**Issue**: FirebaseException: PERMISSION_DENIED
- Verify Firestore security rules are deployed
- Check user is authenticated (not null)
- Ensure userId matches in rules

## 📱 Accessibility

The app supports:
- ✅ Dark mode
- ✅ Large text/font scaling
- ✅ Screen readers (semantic labels on major widgets)
- ⬜ Full localization (English implemented, Sinhala ready)

## 📈 CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) automatically:

1. **Lint & Test**: Runs on every push/PR
   - Format check
   - Static analysis
   - Unit tests
   - Coverage report

2. **Build Android**: Creates debug APK
   - Uploads artifact for download

3. **Integration Tests**: Runs integration tests
   - Uses macOS runner for better emulator support

### Running CI Locally

```bash
# Lint
cd flutter_app
dart format --output=none --set-exit-if-changed .
flutter analyze

# Test
flutter test --coverage

# Build
flutter build apk --debug
```

## 🎓 Learning Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.flutter.dev/)
- [flutter_blue_plus Documentation](https://pub.dev/packages/flutter_blue_plus)
- [Riverpod Documentation](https://riverpod.dev/)
- [ESP32 BLE Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/bluetooth/index.html)

## 📝 License

This project is provided as-is for educational and development purposes.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## 📧 Support

For issues and questions:
- Open a GitHub issue
- Check existing documentation
- Review troubleshooting section

---

**Built with ❤️ for energy efficiency and IoT monitoring**
