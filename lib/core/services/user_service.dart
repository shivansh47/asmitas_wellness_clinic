import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_cure/core/models/app_user.dart'; 

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  Future<void> registerClient({
    required String uid,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? photoUrl, 
  }) async {
    final data = {
      'uid': uid,
      'displayName': displayName ?? '',
      'role': UserRole.client.name,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'assignedDietitianId': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection(_collection).doc(uid).set(data);
  }

  Future<void> createDietitian({
    required String tempId,
    required String displayName,
    required String email,
  }) async {
    final data = {
      'uid': '',
      'displayName': displayName,
      'role': UserRole.dietitian.name,
      'email': email,
      'phoneNumber': null,
      'photoUrl': null,
      'assignedDietitianId': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection(_collection).doc(tempId).set(data);
  }

  Future<void> linkUid({
    required String tempId,
    required String uid,
  }) async {
    await _db.collection(_collection).doc(tempId).update({'uid' : uid});
  }

  Future<AppUser?> fetchByUid(String uid) async{
    final doc = await _db.collection(_collection).doc(uid).get();
    if(!doc.exists) return null;
    return AppUser.fromFirestore(doc.data()!, uid);
  }

  Future<AppUser?> fetchByEmail(String email) async{
    final query = await _db.collection(_collection).where('email', isEqualTo: email).limit(1).get();
    if(query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return AppUser.fromFirestore(doc.data(), doc.id);
  }

  Future<AppUser?> fetchByPhoneNumber(String phoneNumber) async{
    final query = await _db.collection(_collection).where('phoneNumber', isEqualTo: phoneNumber).limit(1).get();
    if(query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return AppUser.fromFirestore(doc.data(), doc.id);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async{
    await _db.collection(_collection).doc(uid).update(fields);
  }

  Future<void> deleteUser(String uid) async{
    await _db.collection(_collection).doc(uid).delete();
  }

  Future<List<AppUser>> fetchAllDietitians() async{
    final query = await _db.collection(_collection).where('role', isEqualTo: UserRole.dietitian.name).get();
    return query.docs.map((doc) => AppUser.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<List<AppUser>> fetchAllClients() async{
    final query = await _db.collection(_collection).where('role', isEqualTo: UserRole.client.name).get();
    return query.docs.map((doc) => AppUser.fromFirestore(doc.data(), doc.id)).toList();
  }

  Stream<AppUser?> streamUser(String uid){
    return _db.collection(_collection).doc(uid).snapshots().map((doc) {
      if(!doc.exists) return null;
      return AppUser.fromFirestore(doc.data()!, uid);
    });
  }
}