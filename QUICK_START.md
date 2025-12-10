# Quick Start Guide - Energy Monitor System

## 🚀 Get Running in 5 Minutes

This guide gets you from zero to a running demo with fake data.

### Prerequisites Check

```bash
# Check Flutter
flutter --version  # Should be >= 3.0.0

# Check Python
python3 --version  # Should be >= 3.10

# Check git
git --version
```

### Step 1: Clone Repository

```bash
git clone https://github.com/gihan001/gihan001.git
cd gihan001
```

### Step 2: Firebase Setup (Quick)

1. **Create Firebase Project**
   - Go to https://console.firebase.google.com/
   - Click "Add project"
   - Name it "energy-monitor-dev"
   - Disable Google Analytics (for quick setup)

2. **Enable Auth**
   - Go to Authentication → Sign-in method
   - Enable "Anonymous"

3. **Enable Firestore**
   - Go to Firestore Database → Create database
   - Start in "test mode" (for development)
   - Choose location closest to you

4. **Get Android Config** (for testing on Android)
   - Go to Project Settings → General
   - Add Android app
   - Package name: `com.example.energy_monitor_app`
   - Download `google-services.json`
   - Place it at: `flutter_app/android/app/google-services.json`

5. **Deploy Security Rules**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login
   firebase login
   
   # Initialize (select your project)
   firebase init firestore
   
   # Copy rules
   cp dev-tools/firestore_rules.json firestore.rules
   
   # Deploy
   firebase deploy --only firestore:rules
   ```

### Step 3: Run Flutter App

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Start app (connect Android device/emulator)
flutter run
```

**First Time:**
- App will open to login screen
- Click "Get Started" (signs in anonymously)
- You'll see empty device list

### Step 4: Run Fake Device

Open a new terminal:

```bash
cd dev-tools

# Install Python dependencies
pip3 install -r requirements.txt

# Get your Firebase service account
# 1. Firebase Console → Project Settings → Service Accounts
# 2. Click "Generate new private key"
# 3. Save as service-account.json in dev-tools/

# Get your user ID
# Option A: From Firebase Console → Authentication → Users tab
# Option B: From Flutter app logs after sign-in

# Run fake device
python3 fake_device.py \
  --credentials service-account.json \
  --user-id YOUR_USER_ID_HERE \
  --device-id demo-device-001 \
  --device-name "Demo Monitor" \
  --interval 5
```

**Expected Output:**
```
Initializing Firebase...
✓ Firebase initialized

✓ Device registered: demo-device-001

🚀 Starting fake device: Demo Monitor
   User ID: xxx
   Device ID: demo-device-001
   Interval: 5s
   Count: infinite

Press Ctrl+C to stop

📊 Reading sent: 342.5W, 228.3V, 1.5A, Total: 0.48Wh
📊 Reading sent: 356.2W, 231.1V, 1.54A, Total: 0.96Wh
...
```

### Step 5: View Dashboard

Back in the Flutter app:
1. Pull down to refresh device list
2. You should see "Demo Monitor"
3. Tap on it to open dashboard
4. Watch live charts update every 5 seconds! 📊

## 🎉 Success!

You now have:
- ✅ Flutter app running
- ✅ Firebase configured
- ✅ Fake device sending data
- ✅ Live dashboard with charts

## Next Steps

### Test BLE Provisioning (with ESP32)

1. Flash firmware to ESP32:
   ```bash
   cd firmware
   platformio run -e esp32dev -t upload
   ```

2. In Flutter app:
   - Tap "Add Device"
   - Scan for BLE devices
   - Select your ESP32
   - Enter WiFi credentials
   - Provision!

### Customize

- **Change update interval**: Edit `--interval` in fake_device.py
- **Add more devices**: Run multiple fake_device.py with different IDs
- **Modify UI**: Edit files in `flutter_app/lib/src/ui/`

### Build APK

```bash
cd flutter_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Install on phone:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Common Issues

### "User not authenticated" error in fake device
- Make sure you're signed in to the app first
- Copy the correct user ID from Firebase Console

### No data showing in app
- Check fake device is running without errors
- Pull down to refresh in the app
- Verify device ID matches

### Flutter build errors
- Run `flutter clean && flutter pub get`
- Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`

### BLE scan finds no devices
- Check ESP32 is powered on
- Verify firmware uploaded successfully
- Check Bluetooth permissions granted in Android settings

## Need Help?

1. Check `ENERGY_MONITOR_README.md` for detailed docs
2. Review `SECURITY_MIGRATION.md` for production security
3. Check GitHub issues
4. Review Firebase Console for errors

---

**Time to first demo: ~5-10 minutes** ⚡

Enjoy building! 🚀
