
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/location_service.dart'; // Import the location service

import '../home/rides_list_screen.dart';
import './login_screen.dart';
import './pending_screen.dart';
import './invite_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // User is not signed in
        if (authSnapshot.connectionState == ConnectionState.active && !authSnapshot.hasData) {
          _locationService.stopTracking(); // Stop tracking when user logs out
          return const LoginScreen();
        }

        // User is signed in, but we need to wait for user data to decide on tracking
        if (!authSnapshot.hasData) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data!;

        // User is signed in, check their status in Firestore
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
               _locationService.stopTracking();
              return const InviteScreen();
            }

            final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
            final userStatus = userData['status'];

            switch (userStatus) {
              case 'approved':
                _locationService.startTracking(); // Start tracking for approved drivers
                return const RidesListScreen();
              case 'pending':
                 _locationService.stopTracking();
                return const PendingScreen();
              case 'blocked':
                 _locationService.stopTracking();
                return const Scaffold(
                  body: Center(
                    child: Text('Your account has been blocked.'),
                  ),
                );
              default:
                 _locationService.stopTracking();
                return const LoginScreen();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking(); // Ensure tracking is stopped when widget is disposed
    super.dispose();
  }
}
