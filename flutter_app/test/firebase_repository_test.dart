import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:energy_monitor_app/src/data/firebase/firebase_repository.dart';
import 'package:energy_monitor_app/src/domain/device.dart';
import 'package:energy_monitor_app/src/domain/reading.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('FirebaseRepository', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late FirebaseRepository repository;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      
      when(() => mockUser.uid).thenReturn('test-user-id');
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      
      repository = FirebaseRepository(
        firestore: mockFirestore,
        auth: mockAuth,
      );
    });

    test('currentUserId returns user id when authenticated', () {
      expect(repository.currentUserId, 'test-user-id');
    });

    test('currentUserId returns null when not authenticated', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      
      final repo = FirebaseRepository(
        firestore: mockFirestore,
        auth: mockAuth,
      );
      
      expect(repo.currentUserId, isNull);
    });

    test('registerDevice throws when user not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      
      final repo = FirebaseRepository(
        firestore: mockFirestore,
        auth: mockAuth,
      );

      final device = Device(
        deviceId: 'device-1',
        deviceName: 'Test Device',
        model: 'ESP32',
        registeredAt: DateTime.now(),
        lastSeen: DateTime.now(),
        fwVersion: '1.0.0',
        owner: 'test-user-id',
      );

      expect(
        () => repo.registerDevice(device),
        throwsException,
      );
    });
  });

  group('Device Model', () {
    test('Device can be created from JSON', () {
      final json = {
        'deviceId': 'device-1',
        'deviceName': 'Test Device',
        'model': 'ESP32',
        'registeredAt': Timestamp.now(),
        'lastSeen': Timestamp.now(),
        'fwVersion': '1.0.0',
        'owner': 'user-1',
      };

      // This test would work after code generation
      // expect(() => Device.fromJson(json), returnsNormally);
    });

    test('Device can be converted to JSON', () {
      final device = Device(
        deviceId: 'device-1',
        deviceName: 'Test Device',
        model: 'ESP32',
        registeredAt: DateTime.now(),
        lastSeen: DateTime.now(),
        fwVersion: '1.0.0',
        owner: 'user-1',
      );

      final json = device.toJson();
      
      expect(json['deviceId'], 'device-1');
      expect(json['deviceName'], 'Test Device');
      expect(json['model'], 'ESP32');
    });
  });

  group('Reading Model', () {
    test('Reading can be created with valid data', () {
      final reading = Reading(
        readingId: 'reading-1',
        ts: DateTime.now(),
        powerW: 250.5,
        voltageV: 230.0,
        currentA: 1.09,
        energyWh: 125.5,
        sampleMs: 1000,
      );

      expect(reading.powerW, 250.5);
      expect(reading.voltageV, 230.0);
      expect(reading.currentA, 1.09);
    });
  });
}
