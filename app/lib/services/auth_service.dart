
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  User? _currentUser;
  Map<String, dynamic>? _userData;

  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;
    if (user != null) {
      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _userData = userDoc.data();
    } else {
      _userData = null;
    }
    notifyListeners();
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
      return credential;
    } catch (e) {
      // Let the UI handle the error message
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String name) async {
    try {
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;

      if (user != null) {
        // Create user document in Firestore with 'pending' status
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'phoneOrEmail': email,
          'role': 'driver', // All signups are drivers
          'status': 'pending', // Initial status
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      notifyListeners();
      return credential;
    } catch (e) {
      rethrow;
    }
_auth.currentUser;
  }

  Future<void> redeemInvite(String code) async {
    if (_currentUser == null) {
      throw Exception("You must be logged in to redeem an invite.");
    }
    try {
      final callable = _functions.httpsCallable('redeemInvite');
      final result = await callable.call({'code': code});
      
      if (result.data['status'] == 'error') {
        throw Exception(result.data['message']);
      }
      // Manually refresh user data from firestore after redeeming
      await _onAuthStateChanged(_currentUser);

    } on FirebaseFunctionsException catch (e) {
        throw Exception(e.message ?? "Failed to redeem invite code.");
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
