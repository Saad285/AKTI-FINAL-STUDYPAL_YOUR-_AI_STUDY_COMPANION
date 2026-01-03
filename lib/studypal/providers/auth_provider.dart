import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Standard import
import 'package:gcr/studypal/Models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- Login Function ---
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        _isLoading = false;
        notifyListeners();
        return 'Email and password cannot be empty.';
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);

      if (!userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        _isLoading = false;
        notifyListeners();
        return 'Please verify your email address first. Check your Gmail inbox.';
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Login failed.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  // --- Register Function ---
  Future<String?> register(
    String email,
    String password,
    String role,
    String name,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (email.trim().isEmpty ||
          password.trim().isEmpty ||
          name.trim().isEmpty) {
        _isLoading = false;
        notifyListeners();
        return 'All fields are required.';
      }

      if (!email.trim().toLowerCase().endsWith('@gmail.com')) {
        _isLoading = false;
        notifyListeners();
        return 'Only Gmail accounts (@gmail.com) are allowed.';
      }

      if (password.length < 6) {
        _isLoading = false;
        notifyListeners();
        return 'Password must be at least 6 characters.';
      }

      String formattedName = name
          .trim()
          .split(' ')
          .map((word) {
            if (word.isEmpty) return '';
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');

      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      try {
        await cred.user!.sendEmailVerification(
          ActionCodeSettings(
            url:
                'https://clroom-55a59.firebaseapp.com/verify?email=${email.trim()}',
            handleCodeInApp: true,
            androidPackageName:
                'com.example.gcr', // Must match your AndroidManifest
            androidInstallApp: true,
          ),
        );
      } catch (e) {
        debugPrint("⚠️ Email sending failed: $e");
      }

      UserModel newUser = UserModel(
        uid: cred.user!.uid,
        email: email.trim(),
        name: formattedName,
        role: role,
      );

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
      return e.message ?? 'Registration failed.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  // --- Google Sign-In (UPDATED FOR v7.2.0) ---
  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize the Singleton (Required in v7)
      // We must await this before using the instance.
      await GoogleSignIn.instance.initialize();

      // 2. Authenticate (Replaces .signIn())
      // In v7, this throws an error if cancelled, so we must wrap in try/catch.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      // Note: In v7 authenticate returns a non-nullable Future<GoogleSignInAccount>
      // IF successful. If the user cancels, it often throws an exception.

      // 3. Strict Check
      if (!googleUser.email.endsWith('@gmail.com')) {
        await GoogleSignIn.instance.signOut();
        _isLoading = false;
        notifyListeners();
        return 'Only real Gmail accounts (@gmail.com) are allowed.';
      }

      // 4. Get Auth Details (SYNCHRONOUS in v7)
      // DO NOT USE 'await' here.
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 5. Create Credential
      // v7 removes 'accessToken' from the auth object.
      // For Firebase on Android/iOS, 'idToken' is usually sufficient.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken:
            null, // Access token is often not needed or handled differently in v7
        idToken: googleAuth.idToken,
      );

      // 6. Sign In to Firebase
      UserCredential cred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // 7. Save User
      if (cred.user != null) {
        String formattedName = cred.user!.displayName ?? 'No Name';
        formattedName = formattedName
            .split(' ')
            .map((word) {
              if (word.isEmpty) return '';
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');

        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (!doc.exists) {
          UserModel userModel = UserModel(
            uid: cred.user!.uid,
            email: cred.user!.email!,
            name: formattedName,
            role: 'Student',
          );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .set(userModel.toMap());
        }
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      // v7 throws generic errors for cancellation, so we log it but don't show a scary error
      debugPrint('❌ Google Sign-In Error: $e');
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        return null; // Ignore cancellation errors
      }
      return 'Google Sign-In failed. Please try again.';
    }
  }

  // --- Reset Password ---
  Future<String?> resetPassword(String email) async {
    try {
      if (email.trim().isEmpty) return 'Please enter email.';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }
}
