import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Added this import
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:gcr/studypal/Models/class_schedule.dart';

class TeacherProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Local list to store created classes for the session
  final List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> get classes => _classes;

  // --- 1. CREATE CLASS (Fixed) ---
  // --- 1. CREATE CLASS (Updated with Unique Code Check) ---
  Future<bool> createClass({
    required String subjectName,
    required String subjectCode,
    required String teacherName,
    required BuildContext context,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Format subject name: first letter capital, rest lowercase
      final formattedSubjectName = subjectName.trim().isEmpty
          ? subjectName
          : subjectName.trim()[0].toUpperCase() +
                subjectName.trim().substring(1).toLowerCase();

      // ---------------------------------------------------------
      // 1. CHECK IF CLASS CODE ALREADY EXISTS
      // ---------------------------------------------------------
      final existingClasses = await FirebaseFirestore.instance
          .collection('classes')
          .where('subjectCode', isEqualTo: subjectCode)
          .get();

      if (existingClasses.docs.isNotEmpty) {
        // If we found a class with this code, stop and show error
        _isLoading = false;
        notifyListeners();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "The Class Code '$subjectCode' is already taken. Please choose another.",
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return false; // Return failure
      }
      // ---------------------------------------------------------

      // 2. If code is unique, proceed to create
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('classes')
          .doc();

      Map<String, dynamic> classData = {
        'classId': docRef.id,
        'teacherId': user.uid,
        'subjectName': formattedSubjectName,
        'subjectCode': subjectCode,
        'teacherName': teacherName,
        'students': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(classData);

      _classes.insert(0, classData);

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true; // Success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return false; // Failure
    }
  }

  // --- 2. UPLOAD MATERIAL (Kept Same) ---
  Future<void> uploadMaterial({
    required String subjectId,
    required String title,
    required String type,
    required PlatformFile file,
    DateTime? deadline,
    String? description,
    required BuildContext context,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (file.path == null) throw Exception("File path is missing.");

      final teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('📤 Uploading ${file.name} to Cloudinary...');
      final cloudinary = CloudinaryPublic(
        'dcawllgca',
        'ml_default',
        cache: false,
      );

      CloudinaryResponse response = await cloudinary
          .uploadFile(
            CloudinaryFile.fromFile(
              file.path!,
              resourceType: CloudinaryResourceType.Auto,
              folder: subjectId,
            ),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException('Upload timeout'),
          );

      debugPrint('✅ File uploaded to Cloudinary: ${response.secureUrl}');

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(subjectId)
          .collection('materials')
          .add({
            'title': title,
            'description': description ?? "",
            'type': type,
            'classId': subjectId,
            'createdBy': teacherId,
            'fileUrl': response.secureUrl,
            'fileName': file.name,
            'fileExtension': file.extension,
            'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
            'uploadedAt': FieldValue.serverTimestamp(),
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Firestore save timeout'),
          );

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Material saved to Firestore successfully');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material Posted Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on TimeoutException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Upload timeout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload timeout. Please check your connection and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      if (context.mounted) {
        String message = 'Upload failed.';
        if (e.code == 'permission-denied') {
          message = 'Permission denied. Check Firestore security rules.';
        } else if (e.code == 'unavailable') {
          message = 'Network error. Please check your connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Upload error: $e');
      if (context.mounted) {
        String message = 'Upload Failed: $e';
        if (e.toString().contains('network')) {
          message = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('authentication')) {
          message = 'Authentication error. Please sign in again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- 3. ADD CLASS SCHEDULE (Updated) ---
  Future<void> addClassSchedule({
    required String classId,
    required String teacherId, // Currently logged in user ID
    required String day,
    required String time,
    required String subjectName,
    required String type,
    required String location, // Room or Link
    // required BuildContext context, // Removed context dependency for pure logic if needed
  }) async {
    // Note: We don't set global isLoading here to avoid rebuilding the whole screen
    // The dialog handles its own loading state usually, or we can use local state.

    try {
      // Determine room/link based on type
      String roomNumber = type == 'On Campus' ? location : '';
      String classLink = type == 'Online' ? location : '';

      final schedule = ClassSchedule(
        id: '', // Firestore will generate
        classId: classId,
        teacherId:
            teacherId, // Important: Ensure this is passed correctly from UI
        day: day,
        time: time,
        subjectName: subjectName,
        type: type,
        roomNumber: roomNumber,
        classLink: classLink,
        createdAt: DateTime.now(),
      );

      // Save to 'schedules' collection (matches TodayScheduleWidget query)
      await FirebaseFirestore.instance
          .collection('schedules')
          .add(schedule.toMap());

      notifyListeners();
    } catch (e) {
      rethrow; // Pass error back to UI to handle
    }
  }

  // --- EDIT MATERIAL ---
  Future<void> editMaterial({
    required String subjectId,
    required String materialId,
    String? title,
    String? description,
    DateTime? deadline,
    required BuildContext context,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      Map<String, dynamic> updateData = {};

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (deadline != null) {
        updateData['deadline'] = Timestamp.fromDate(deadline);
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(subjectId)
            .collection('materials')
            .doc(materialId)
            .update(updateData);
      }

      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
      }
    }
  }
}
