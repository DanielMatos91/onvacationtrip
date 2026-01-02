
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class RidesListScreen extends StatelessWidget {
  const RidesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? driverId = FirebaseAuth.instance.currentUser?.uid;

    if (driverId == null) {
      return const Scaffold(body: Center(child: Text('Error: Not logged in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () => context.go('/support'),
            tooltip: 'Support',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('driverId', isEqualTo: driverId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No rides assigned to you yet.\nCheck back later!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final rides = snapshot.data!.docs;

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              final rideData = ride.data() as Map<String, dynamic>;

              final pickup = rideData['pickup']?['address'] ?? 'No pickup address';
              final dropoff = rideData['dropoff']?['address'] ?? 'No dropoff address';
              final status = rideData['status'] ?? 'Unknown';
              final price = rideData['price']?.toString() ?? 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('From: $pickup'),
                  subtitle: Text('To: $dropoff\nStatus: $status - R\$ $price'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.go('/ride/${ride.id}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
