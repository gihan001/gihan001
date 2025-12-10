import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../data/firebase/firebase_repository.dart';
import '../data/ble/ble_provisioning_service.dart';
import '../domain/device.dart';
import '../domain/reading.dart';

// Logger provider
final loggerProvider = Provider<Logger>((ref) => Logger());

// Firebase Repository
final firebaseRepositoryProvider = Provider<FirebaseRepository>((ref) {
  return FirebaseRepository(logger: ref.watch(loggerProvider));
});

// BLE Provisioning Service
final bleProvisioningServiceProvider = Provider<BleProvisioningService>((ref) {
  final service = BleProvisioningService(logger: ref.watch(loggerProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

// Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.authStateChanges();
});

// User Devices
final userDevicesProvider = StreamProvider<List<Device>>((ref) {
  final repository = ref.watch(firebaseRepositoryProvider);
  return repository.watchUserDevices();
});

// Device Readings - requires deviceId parameter
final deviceReadingsProvider = StreamProvider.family<List<Reading>, String>(
  (ref, deviceId) {
    final repository = ref.watch(firebaseRepositoryProvider);
    return repository.watchDeviceReadings(deviceId);
  },
);

// Selected Device State
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// BLE Scan Results
final bleScanResultsProvider = StreamProvider((ref) {
  final service = ref.watch(bleProvisioningServiceProvider);
  return service.scanForDevices();
});

// Bluetooth Adapter State
final bluetoothAdapterStateProvider = StreamProvider((ref) {
  return BleProvisioningService.adapterStateStream;
});
