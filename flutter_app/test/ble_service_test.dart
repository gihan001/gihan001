import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:energy_monitor_app/src/data/ble/ble_provisioning_service.dart';
import 'package:energy_monitor_app/src/domain/provisioning_data.dart';

// Note: Testing BLE is complex due to platform dependencies
// These are basic structure tests

void main() {
  group('BleProvisioningService', () {
    late BleProvisioningService service;

    setUp(() {
      service = BleProvisioningService();
    });

    tearDown(() {
      service.dispose();
    });

    test('BleUuids are correctly defined', () {
      expect(BleUuids.serviceUuid.toString(), 
             '0000feed-0000-1000-8000-00805f9b34fb');
      expect(BleUuids.provisioningWriteUuid.toString(), 
             '0000beef-0000-1000-8000-00805f9b34fb');
      expect(BleUuids.statusNotifyUuid.toString(), 
             '0000cafe-0000-1000-8000-00805f9b34fb');
    });

    test('ProvisioningData can be created', () {
      final data = ProvisioningData(
        ssid: 'TestWiFi',
        pass: 'password123',
        tz: 'Asia/Colombo',
        deviceName: 'Test Device',
      );

      expect(data.ssid, 'TestWiFi');
      expect(data.pass, 'password123');
      expect(data.protoVersion, '1.0');
    });

    test('ProvisioningData can be serialized to JSON', () {
      final data = ProvisioningData(
        ssid: 'TestWiFi',
        pass: 'password123',
        tz: 'Asia/Colombo',
        deviceName: 'Test Device',
      );

      final json = data.toJson();

      expect(json['ssid'], 'TestWiFi');
      expect(json['pass'], 'password123');
      expect(json['tz'], 'Asia/Colombo');
      expect(json['deviceName'], 'Test Device');
      expect(json['protoVersion'], '1.0');
    });
  });
}
