import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/screens/splash_screen.dart';

class LoginController {
   static Future <void> loginAccount({required BuildContext context,required String email, required String password}) async {
    try{
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    print("Account created successfully.");
     Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context){
      return SplashScreen();
    }),(route){
        return false;
    });
    }catch(e){
      print(e);
      SnackBar messageSnackBar = SnackBar(content: Text(e.toString()));
      ScaffoldMessenger.of(context).showSnackBar(messageSnackBar);
    }
  }
}