
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phoneOrEmail;
  final String role; // "admin" | "driver"
  final String status; // "pending" | "approved" | "blocked"
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phoneOrEmail,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phoneOrEmail: data['phoneOrEmail'] ?? '',
      role: data['role'] ?? 'driver',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phoneOrEmail': phoneOrEmail,
      'role': role,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
