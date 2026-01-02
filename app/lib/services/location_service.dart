
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  Future<void> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  void startTracking() async {
    if (_isTracking) return;

    await _handleLocationPermission();

    final user = _auth.currentUser;
    if (user == null) return; // Not logged in

    // Check driver status before starting to track
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists || userDoc.data()?['status'] != 'approved') {
      return; // Do not track if user is not approved
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _updateDriverLocation(user.uid, position);
    });

    _isTracking = true;
  }

  void _updateDriverLocation(String driverId, Position position) {
    _firestore.collection('driver_locations').doc(driverId).set({
      'location': GeoPoint(position.latitude, position.longitude),
      'updatedAt': FieldValue.serverTimestamp(),
      'driverId': driverId,
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _isTracking = false;
  }
}
