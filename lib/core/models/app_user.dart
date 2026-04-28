import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole{admin, dietitian, client, unknown}

class AppUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;
  final String? assignedDietitianId;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.assignedDietitianId
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid){
    return AppUser(
      uid: uid,
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.unknown
      ),
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      assignedDietitianId: data['assignedDietitianId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'uid' : uid,
    'displayName' : displayName,
    'role' : role.name,
    'email' : email,
    'phoneNumber' : phoneNumber,
    'photoUrl' : photoUrl,
    'assignedDietitianId' : assignedDietitianId,
    'createdAt' : FieldValue.serverTimestamp()
  };
}