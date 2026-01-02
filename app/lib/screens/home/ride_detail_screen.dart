
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, String> _statusTransitions = {
    'assigned': 'accepted',
    'accepted': 'arrived',
    'arrived': 'started',
    'started': 'finished',
  };

  Future<void> _updateRideStatus(String nextStatus) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('driverUpdateRideStatus');
      await callable.call({
        'rideId': widget.rideId,
        'nextStatus': nextStatus,
      });
      // UI will update automatically thanks to the StreamBuilder
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "An unknown error occurred.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Ride Details'),
    ),
    body: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Ride not found.'));
        }

        final rideData = snapshot.data!.data() as Map<String, dynamic>;
        final currentStatus = rideData['status'] as String;
        final nextStatus = _statusTransitions[currentStatus];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDetailCard('Status', currentStatus.toUpperCase(), context),
              const SizedBox(height: 16),
              _buildDetailCard('Passenger', rideData['passengerName'], context),
              const SizedBox(height: 16),
              _buildDetailCard('From', rideData['pickup']?['address'], context),
              const SizedBox(height: 16),
              _buildDetailCard('To', rideData['dropoff']?['address'], context),
              const SizedBox(height: 16),
              _buildDetailCard('Price', 'R\$ ${rideData['price']?.toStringAsFixed(2)}', context),
              const SizedBox(height: 16),
              if (rideData['notes'] != null && rideData['notes'].isNotEmpty)
                _buildDetailCard('Notes', rideData['notes'], context),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              if (nextStatus != null && !_isLoading)
                ElevatedButton(
                  onPressed: () => _updateRideStatus(nextStatus),
                  child: Text('Mark as ${nextStatus.toUpperCase()}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              if (currentStatus == 'finished')
                const Center(child: Chip(label: Text('Ride Completed'), backgroundColor: Colors.green)),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildDetailCard(String title, String? value, BuildContext context) {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value ?? 'N/A', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
}

}
