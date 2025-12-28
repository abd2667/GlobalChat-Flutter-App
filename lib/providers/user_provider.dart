import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String userName = "";
  String userEmail = "";
  String userId = "";
  String profileImage = "";
  String country = "";

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> getData() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    try {
      final dataSnapshot = await _db.collection("users").doc(authUser.uid).get();
      final data = dataSnapshot.data();
      
      if (data != null) {
        userName = data["name"] ?? "";
        userEmail = data["email"] ?? "";
        userId = data["id"] ?? "";
        profileImage = data["profile_image"] ?? "";
        country = data["country"] ?? "";
        
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }
}