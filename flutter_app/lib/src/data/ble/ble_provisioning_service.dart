import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import '../domain/provisioning_data.dart';

/// BLE GATT Service and Characteristic UUIDs
class BleUuids {
  static final serviceUuid = Guid('0000feed-0000-1000-8000-00805f9b34fb');
  static final provisioningWriteUuid = Guid('0000beef-0000-1000-8000-00805f9b34fb');
  static final statusNotifyUuid = Guid('0000cafe-0000-1000-8000-00805f9b34fb');
}

enum ProvisioningStatus {
  idle,
  connecting,
  writing,
  waiting,
  success,
  error,
}

class BleProvisioningService {
  final Logger _logger;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  BleProvisioningService({Logger? logger}) : _logger = logger ?? Logger();

  /// Scan for devices advertising our service
  Stream<ScanResult> scanForDevices({Duration timeout = const Duration(seconds: 10)}) {
    _logger.i('Starting BLE scan...');
    
    FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [BleUuids.serviceUuid],
    );

    return FlutterBluePlus.scanResults.map((results) => results.last);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a device and discover services
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _logger.i('Connecting to device: ${device.remoteId}');
      
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Discover services
      final services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid == BleUuids.serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == BleUuids.provisioningWriteUuid) {
              _writeCharacteristic = characteristic;
              _logger.d('Found provisioning write characteristic');
            } else if (characteristic.uuid == BleUuids.statusNotifyUuid) {
              _notifyCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              
              // Listen for status notifications
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  try {
                    final jsonStr = utf8.decode(value);
                    final status = jsonDecode(jsonStr) as Map<String, dynamic>;
                    _logger.i('Status notification: $status');
                    _statusController.add(status);
                  } catch (e) {
                    _logger.e('Error parsing status notification: $e');
                  }
                }
              });
              
              _logger.d('Found and subscribed to status notify characteristic');
            }
          }
        }
      }

      if (_writeCharacteristic == null || _notifyCharacteristic == null) {
        throw Exception('Required characteristics not found');
      }

      _logger.i('Device connected and characteristics discovered');
    } catch (e) {
      _logger.e('Error connecting to device: $e');
      await disconnect();
      rethrow;
    }
  }

  /// Provision device with WiFi credentials (Option B - Simpler)
  /// Note: In production, use Option A with encryption
  Future<void> provisionDevice(ProvisioningData data) async {
    if (_writeCharacteristic == null) {
      throw Exception('Not connected to device');
    }

    try {
      _logger.i('Starting provisioning...');
      
      final jsonData = jsonEncode(data.toJson());
      final bytes = utf8.encode(jsonData);

      // Check MTU and chunk if necessary
      final mtu = await _connectedDevice!.mtu.first;
      final maxChunkSize = mtu - 3; // Reserve 3 bytes for ATT overhead

      if (bytes.length <= maxChunkSize) {
        // Send in one go
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
        _logger.i('Provisioning data sent');
      } else {
        // Send in chunks
        for (var i = 0; i < bytes.length; i += maxChunkSize) {
          final end = (i + maxChunkSize < bytes.length) 
              ? i + maxChunkSize 
              : bytes.length;
          final chunk = bytes.sublist(i, end);
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
          _logger.d('Sent chunk ${i ~/ maxChunkSize + 1}');
          await Future.delayed(const Duration(milliseconds: 50));
        }
        _logger.i('Provisioning data sent in chunks');
      }
    } catch (e) {
      _logger.e('Error during provisioning: $e');
      rethrow;
    }
  }

  /// Provision device with encryption (Option A - Secure)
  /// This is a placeholder for the secure implementation
  /// In production, implement ECDH key exchange and AES-GCM encryption
  Future<void> provisionDeviceSecure(
    ProvisioningData data,
    String devicePublicKey,
  ) async {
    // TODO: Implement Option A
    // 1. Parse devicePublicKey (base64 Curve25519)
    // 2. Generate ephemeral key pair
    // 3. Perform ECDH to get shared secret
    // 4. Derive AES-GCM key
    // 5. Encrypt provisioning data
    // 6. Send encrypted payload
    _logger.w('Secure provisioning not yet implemented, falling back to basic');
    await provisionDevice(data);
  }

  /// Wait for provisioning result with timeout
  Future<Map<String, dynamic>> waitForProvisioningResult({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final result = await statusStream
          .firstWhere(
            (status) => status['status'] == 'ok' || status['status'] == 'err',
            orElse: () => {'status': 'err', 'msg': 'timeout'},
          )
          .timeout(timeout);
      
      return result;
    } catch (e) {
      _logger.e('Timeout waiting for provisioning result: $e');
      return {'status': 'err', 'msg': 'timeout'};
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _logger.i('Disconnected from device');
    }
  }

  void dispose() {
    _statusController.close();
    disconnect();
  }

  /// Check if Bluetooth is available and enabled
  static Future<bool> isBluetoothAvailable() async {
    if (await FlutterBluePlus.isSupported == false) {
      return false;
    }
    return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  /// Get adapter state stream
  static Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;
}
