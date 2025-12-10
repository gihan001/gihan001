# Security Migration Guide: Option B → Option A

## Overview

This guide explains how to migrate from the basic BLE security (Option B) to encrypted provisioning (Option A) using ECDH + AES-GCM.

## Current State (Option B)

Currently, the system uses BLE Secure Connections with link-layer encryption. WiFi credentials are sent as plaintext JSON over the encrypted BLE link.

**Risks:**
- Vulnerable to MITM attacks if BLE pairing is compromised
- Relies solely on BLE link-layer security
- Not suitable for production deployment

## Target State (Option A)

Implement end-to-end encryption using:
- Curve25519 for key exchange (ECDH)
- AES-256-GCM for data encryption
- Device-unique key pairs

## Implementation Steps

### 1. ESP32 Firmware Changes

#### Generate Device Key Pair (First Boot)

```cpp
#include <mbedtls/ecdh.h>
#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>

// Storage for device keys
mbedtls_ecdh_context deviceKeyCtx;
unsigned char devicePrivateKey[32];
unsigned char devicePublicKey[32];

void generateDeviceKeys() {
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_ecdh_init(&deviceKeyCtx);
    
    // Seed RNG
    const char *pers = "energy_monitor_ecdh";
    mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                          (const unsigned char *)pers, strlen(pers));
    
    // Generate key pair
    mbedtls_ecp_group_load(&deviceKeyCtx.grp, MBEDTLS_ECP_DP_CURVE25519);
    mbedtls_ecdh_gen_public(&deviceKeyCtx.grp, &deviceKeyCtx.d, &deviceKeyCtx.Q,
                            mbedtls_ctr_drbg_random, &ctr_drbg);
    
    // Export public key
    size_t olen;
    mbedtls_mpi_write_binary(&deviceKeyCtx.Q.X, devicePublicKey, 32);
    
    // Store keys in NVS for persistence
    saveKeysToNVS(devicePrivateKey, devicePublicKey);
    
    Serial.println("Device keys generated");
}
```

#### Advertise Public Key

```cpp
void setupBLE() {
    // ... existing setup ...
    
    // Add device public key to advertisement manufacturer data
    String pubKeyB64 = base64_encode(devicePublicKey, 32);
    
    NimBLEAdvertisementData advData;
    advData.setManufacturerData(pubKeyB64.c_str());
    pAdvertising->setAdvertisementData(advData);
}
```

#### Decrypt Provisioning Data

```cpp
#include <mbedtls/gcm.h>

bool decryptProvisioningData(const uint8_t* encryptedData, size_t dataLen,
                             String& ssid, String& password) {
    // Parse encrypted payload
    // Format: [ephemeralPubKey(32)] [nonce(12)] [ciphertext] [tag(16)]
    
    if (dataLen < 32 + 12 + 16) {
        Serial.println("Invalid encrypted payload");
        return false;
    }
    
    const uint8_t* ephemeralPubKey = encryptedData;
    const uint8_t* nonce = encryptedData + 32;
    const uint8_t* ciphertext = encryptedData + 32 + 12;
    const uint8_t* tag = encryptedData + dataLen - 16;
    size_t ciphertextLen = dataLen - 32 - 12 - 16;
    
    // Perform ECDH to get shared secret
    mbedtls_mpi ephemeralPubKeyMpi;
    mbedtls_mpi_init(&ephemeralPubKeyMpi);
    mbedtls_mpi_read_binary(&ephemeralPubKeyMpi, ephemeralPubKey, 32);
    
    unsigned char sharedSecret[32];
    mbedtls_ecdh_compute_shared(&deviceKeyCtx.grp, &deviceKeyCtx.z,
                                &ephemeralPubKeyMpi, &deviceKeyCtx.d,
                                mbedtls_ctr_drbg_random, &ctr_drbg);
    mbedtls_mpi_write_binary(&deviceKeyCtx.z, sharedSecret, 32);
    
    // Decrypt with AES-GCM
    mbedtls_gcm_context gcmCtx;
    mbedtls_gcm_init(&gcmCtx);
    mbedtls_gcm_setkey(&gcmCtx, MBEDTLS_CIPHER_ID_AES, sharedSecret, 256);
    
    unsigned char plaintext[512];
    int ret = mbedtls_gcm_auth_decrypt(&gcmCtx, ciphertextLen,
                                       nonce, 12,
                                       NULL, 0,  // No additional authenticated data
                                       tag, 16,
                                       ciphertext,
                                       plaintext);
    
    mbedtls_gcm_free(&gcmCtx);
    
    if (ret != 0) {
        Serial.printf("Decryption failed: %d\n", ret);
        return false;
    }
    
    // Parse JSON
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, plaintext, ciphertextLen);
    
    if (error) {
        Serial.println("JSON parse error after decryption");
        return false;
    }
    
    ssid = doc["ssid"].as<String>();
    password = doc["pass"].as<String>();
    
    return true;
}
```

### 2. Flutter App Changes

#### Add Cryptography Package

```yaml
# pubspec.yaml
dependencies:
  cryptography: ^2.5.0
```

#### Implement Secure Provisioning

```dart
// lib/src/data/ble/ble_crypto.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class BleEncryption {
  static Future<Uint8List> encryptProvisioningData(
    String devicePublicKeyBase64,
    Map<String, dynamic> provisioningData,
  ) async {
    // Parse device public key
    final devicePubKeyBytes = base64Decode(devicePublicKeyBase64);
    final devicePublicKey = SimplePublicKey(
      devicePubKeyBytes,
      type: KeyPairType.x25519,
    );
    
    // Generate ephemeral key pair
    final algorithm = X25519();
    final ephemeralKeyPair = await algorithm.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    
    // Perform ECDH
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: devicePublicKey,
    );
    
    // Encrypt with AES-GCM
    final cipher = AesGcm.with256bits();
    final plaintext = utf8.encode(jsonEncode(provisioningData));
    
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: sharedSecret,
    );
    
    // Build payload: [ephemeralPubKey(32)] [nonce(12)] [ciphertext] [mac(16)]
    final payload = BytesBuilder();
    payload.add(ephemeralPublicKey.bytes);
    payload.add(secretBox.nonce);
    payload.add(secretBox.cipherText);
    payload.add(secretBox.mac.bytes);
    
    return payload.toBytes();
  }
}
```

#### Update BLE Service

```dart
// lib/src/data/ble/ble_provisioning_service.dart
import 'ble_crypto.dart';

Future<void> provisionDeviceSecure(
  ProvisioningData data,
  String devicePublicKeyBase64,
) async {
  if (_writeCharacteristic == null) {
    throw Exception('Not connected to device');
  }

  try {
    _logger.i('Starting secure provisioning...');
    
    // Encrypt provisioning data
    final encryptedPayload = await BleEncryption.encryptProvisioningData(
      devicePublicKeyBase64,
      data.toJson(),
    );

    // Send encrypted payload
    final mtu = await _connectedDevice!.mtu.first;
    final maxChunkSize = mtu - 3;

    if (encryptedPayload.length <= maxChunkSize) {
      await _writeCharacteristic!.write(encryptedPayload, withoutResponse: true);
    } else {
      // Send in chunks
      for (var i = 0; i < encryptedPayload.length; i += maxChunkSize) {
        final end = (i + maxChunkSize < encryptedPayload.length)
            ? i + maxChunkSize
            : encryptedPayload.length;
        final chunk = encryptedPayload.sublist(i, end);
        await _writeCharacteristic!.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    
    _logger.i('Encrypted provisioning data sent');
  } catch (e) {
    _logger.e('Error during secure provisioning: $e');
    rethrow;
  }
}
```

#### Retrieve Device Public Key

```dart
// Add a characteristic for device public key or parse from advertisement
Future<String> getDevicePublicKey() async {
  // Option 1: From advertisement manufacturer data
  final advData = _connectedDevice!.advertisementData;
  if (advData.manufacturerData.isNotEmpty) {
    return utf8.decode(advData.manufacturerData.values.first);
  }
  
  // Option 2: From a dedicated characteristic
  // Implement characteristic read for public key
  throw Exception('Device public key not found');
}
```

### 3. Update Provisioning Flow

```dart
// lib/src/ui/screens/provisioning_screen.dart
Future<void> _startSecureProvisioning() async {
  // ... existing validation ...
  
  try {
    final bleService = ref.read(bleProvisioningServiceProvider);
    
    // Connect to device
    await bleService.connectToDevice(widget.device);
    
    // Get device public key
    final devicePubKey = await bleService.getDevicePublicKey();
    
    // Prepare provisioning data
    final provisioningData = ProvisioningData(
      ssid: _ssidController.text,
      pass: _passwordController.text,
      tz: 'Asia/Colombo',
      deviceName: _deviceNameController.text,
    );

    // Send with encryption
    await bleService.provisionDeviceSecure(
      provisioningData,
      devicePubKey,
    );
    
    // Wait for result
    final result = await bleService.waitForProvisioningResult();
    
    // Handle result...
  } catch (e) {
    // Handle error...
  }
}
```

## Testing Secure Implementation

### Unit Tests

```dart
// test/ble_crypto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:energy_monitor_app/src/data/ble/ble_crypto.dart';

void main() {
  test('Encryption produces valid payload', () async {
    final devicePubKey = 'base64EncodedPublicKey...';
    final data = {'ssid': 'TestWiFi', 'pass': 'password'};
    
    final encrypted = await BleEncryption.encryptProvisioningData(
      devicePubKey,
      data,
    );
    
    expect(encrypted.length, greaterThan(32 + 12 + 16));
  });
}
```

### Integration Testing

1. Flash updated firmware to ESP32
2. Run Flutter app with secure provisioning
3. Monitor serial output for successful decryption
4. Verify WiFi connection

## Rollout Strategy

### Phase 1: Parallel Implementation
- Keep Option B functional
- Add Option A alongside
- Feature flag to switch between modes

### Phase 2: Testing
- Test with small user group
- Monitor for decryption failures
- Gather metrics on success rate

### Phase 3: Migration
- Default new devices to Option A
- Gradually migrate existing devices via firmware OTA
- Maintain Option B for legacy support

### Phase 4: Deprecation
- After 90% migration, deprecate Option B
- Remove Option B code in next major version

## Security Checklist

- [ ] Device keys generated at manufacturing or first boot
- [ ] Private keys never leave device
- [ ] Public keys properly advertised
- [ ] ECDH properly implemented with Curve25519
- [ ] AES-GCM encryption with 256-bit keys
- [ ] Nonce/IV never reused
- [ ] Authentication tag verified on device
- [ ] Rate limiting on provisioning attempts
- [ ] Secure storage for device keys (NVS encryption)
- [ ] Firmware signed and verified for OTA
- [ ] Audit logging for provisioning events

## References

- [mbedtls Documentation](https://tls.mbed.org/)
- [Cryptography Package for Dart](https://pub.dev/packages/cryptography)
- [RFC 7748 - Curve25519](https://tools.ietf.org/html/rfc7748)
- [NIST SP 800-38D - GCM](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf)

## Support

For implementation questions:
1. Review this guide
2. Check example code in repository
3. Open GitHub issue with "Security" label
