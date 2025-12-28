import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:globalchat/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupController {
  static Future<void> createAccount({
    required BuildContext context,
    required String name,
    required String country,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    try {
      // 1. Create Firebase Auth Account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String userId = userCredential.user!.uid;
      String? profileImageUrl;

      // 2. Upload Profile Image to Supabase if exists
      if (profileImage != null) {
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storage = Supabase.instance.client.storage;

        try {
          await storage.from('chat_files').upload('profiles/$fileName', profileImage);
          profileImageUrl = storage.from('chat_files').getPublicUrl('profiles/$fileName');
        } catch (e) {
          print("Supabase Upload Error: $e");
        }
      }

      // 3. Save User Data to Firestore
      var db = FirebaseFirestore.instance;
      Map<String, dynamic> data = {
        "name": name,
        "email": email,
        "country": country,
        "id": userId,
        "profile_image": profileImageUrl ?? "",
        "created_at": FieldValue.serverTimestamp(),
        "status": "Online",
      };

      await db.collection("users").doc(userId).set(data);

      print("Account created successfully.");

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print(e);
      if (context.mounted) {
        SnackBar messageSnackBar = SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        );
        ScaffoldMessenger.of(context).showSnackBar(messageSnackBar);
      }
    }
  }
}
