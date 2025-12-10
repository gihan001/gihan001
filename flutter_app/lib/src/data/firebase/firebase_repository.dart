import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../domain/device.dart';
import '../domain/reading.dart';

class FirebaseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;

  FirebaseRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Logger? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _logger = logger ?? Logger();

  String? get currentUserId => _auth.currentUser?.uid;

  // Device operations
  Future<void> registerDevice(Device device) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(device.deviceId)
        .set(device.toJson());
    
    _logger.i('Device registered: ${device.deviceId}');
  }

  Stream<List<Device>> watchUserDevices() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Device.fromJson({...doc.data(), 'deviceId': doc.id}))
          .toList();
    });
  }

  Future<Device?> getDevice(String deviceId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .get();

    if (!doc.exists) return null;
    return Device.fromJson({...doc.data()!, 'deviceId': doc.id});
  }

  // Reading operations
  Stream<List<Reading>> watchDeviceReadings(
    String deviceId, {
    int limit = 100,
  }) {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .collection('readings')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              Reading.fromJson({...doc.data(), 'readingId': doc.id}))
          .toList();
    });
  }

  Future<List<Reading>> getReadingsInRange(
    String deviceId,
    DateTime start,
    DateTime end,
  ) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .collection('readings')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('ts', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('ts', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Reading.fromJson({...doc.data(), 'readingId': doc.id}))
        .toList();
  }

  // Update device last seen
  Future<void> updateDeviceLastSeen(String deviceId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .update({'lastSeen': FieldValue.serverTimestamp()});
  }

  // Authentication helpers
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
