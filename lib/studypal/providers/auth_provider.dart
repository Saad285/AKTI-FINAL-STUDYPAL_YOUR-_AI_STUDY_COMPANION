import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gcr/studypal/Models/UserModels.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  // --- Register Function ---
  Future<String?> register(
    String email,
    String password,
    String role,
    String name, // Input: "muhammad saad zia"
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. FORMAT THE NAME (The Fix)
      // This converts "muhammad saad zia" -> "Muhammad Saad Zia"
      String formattedName = name
          .trim()
          .split(' ')
          .map((word) {
            if (word.isEmpty) return '';
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');

      // 2. Create Auth User
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 3. Create Model using the FORMATTED Name
      UserModel newUser = UserModel(
        uid: cred.user!.uid,
        email: email,
        name: formattedName, // <--- Saving the formatted name here
        role: role,
      );

      // 4. Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(newUser.toMap());

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'weak-password') return 'The password is too weak.';
      if (e.code == 'email-already-in-use') {
        return 'The email is already in use.';
      }
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Error: ${e.toString()}";
    }
  }
}
