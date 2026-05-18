import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.get('role') as String).toLowerCase().trim();
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    return 'student';
  }

  Future<String?> getCurrentUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) return await getUserRole(user.uid);
    return null;
  }

  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String department,
    required String studentId,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'department': department,
        'fullName': fullName,
        'studentId': studentId,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("Sign out error: $e");
    }
  }

  Future<String?> promoteToHod(String uid, String department) async {
    try {
      QuerySnapshot existingHod = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'hod')
          .where('department', isEqualTo: department)
          .get();

      if (existingHod.docs.isNotEmpty) {
        String hodName = existingHod.docs.first['fullName'] ?? "Another user";
        return "Conflict: $hodName is already the HOD for $department.";
      }

      await _firestore.collection('users').doc(uid).update({'role': 'hod'});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<Map<String, dynamic>>> getUnifiedTimeline() async {
    if (_auth.currentUser == null) return [];

    List<Map<String, dynamic>> timeline = [];
    final now = DateTime.now();

    try {
      var events = await _firestore.collection('events').get();
      for (var doc in events.docs) {
        final data = doc.data();
        DateTime? date = (data['startDate'] as Timestamp?)?.toDate();
        if (date != null && date.isAfter(now.subtract(const Duration(days: 1)))) {
          timeline.add({...data, 'id': doc.id, 'type': 'event', 'sortDate': date});
        }
      }

      var holidays = await _firestore.collection('holidays').get();
      for (var doc in holidays.docs) {
        final data = doc.data();
        DateTime? date = (data['startDate'] as Timestamp?)?.toDate();
        if (date != null && date.isAfter(now.subtract(const Duration(days: 1)))) {
          timeline.add({...data, 'id': doc.id, 'type': 'holiday', 'sortDate': date});
        }
      }

      var alerts = await _firestore.collection('alerts').get();
      for (var doc in alerts.docs) {
        final data = doc.data();
        DateTime? created = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
        timeline.add({...data, 'id': doc.id, 'type': 'alert', 'sortDate': created});
      }

      timeline.sort((a, b) {
        if (a['type'] == 'alert' && b['type'] != 'alert') return -1;
        if (a['type'] != 'alert' && b['type'] == 'alert') return 1;
        return (a['sortDate'] as DateTime).compareTo(b['sortDate'] as DateTime);
      });
    } catch (e) {
      debugPrint("Error fetching timeline: $e");
    }
    return timeline;
  }
}