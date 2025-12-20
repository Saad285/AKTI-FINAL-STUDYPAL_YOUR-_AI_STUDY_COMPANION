import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gcr/studypal/Models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        _isLoading = false;
        notifyListeners();
        return 'Email and password cannot be empty.';
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'invalid-credential':
          return 'Invalid credentials. Please check your email and password.';
        default:
          return e.message ?? 'Login failed. Please try again.';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Unexpected login error: $e');
      return 'An unexpected error occurred. Please try again.';
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
      // Input validation
      if (email.trim().isEmpty ||
          password.trim().isEmpty ||
          name.trim().isEmpty) {
        _isLoading = false;
        notifyListeners();
        return 'All fields are required.';
      }

      if (password.length < 6) {
        _isLoading = false;
        notifyListeners();
        return 'Password must be at least 6 characters.';
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _isLoading = false;
        notifyListeners();
        return 'Please enter a valid email address.';
      }

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
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      if (cred.user == null) {
        throw Exception('Failed to create user account');
      }

      // 3. Create Model using the FORMATTED Name
      UserModel newUser = UserModel(
        uid: cred.user!.uid,
        email: email.trim(),
        name: formattedName, // <--- Saving the formatted name here
        role: role,
      );

      // 4. Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(newUser.toMap())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Failed to save user data'),
          );

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ User registered successfully: ${cred.user!.uid}');
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'operation-not-allowed':
          return 'Registration is currently disabled.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        default:
          return e.message ?? 'Registration failed. Please try again.';
      }
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Firestore Error: ${e.code}');
      // Try to delete the auth user if Firestore save failed
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      return 'Failed to save user data. Please try again.';
    } on TimeoutException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Timeout Error: $e');
      return 'Request timeout. Please check your connection.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Unexpected registration error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // --- Reset Password Function ---
  Future<String?> resetPassword(String email) async {
    try {
      if (email.trim().isEmpty) {
        return 'Please enter your email address.';
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        return 'Please enter a valid email address.';
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

      debugPrint('✅ Password reset email sent to: $email');
      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        default:
          return e.message ?? 'Failed to send reset email. Please try again.';
      }
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
