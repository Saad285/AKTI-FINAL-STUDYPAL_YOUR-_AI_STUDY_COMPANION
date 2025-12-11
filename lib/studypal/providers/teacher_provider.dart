import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage
import 'package:file_picker/file_picker.dart'; // Import PlatformFile

class TeacherProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> createClass({
    required String subjectName,
    required String subjectCode,
    required String teacherName,
    required BuildContext context,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Create a reference to the 'classes' collection
      // You can generate a random ID or let Firestore do it
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('classes')
          .doc();

      // 2. Prepare the data
      Map<String, dynamic> classData = {
        'classId': docRef.id,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
        // Add other fields if needed, e.g., 'teacherId': FirebaseAuth.instance.currentUser!.uid,
      };

      // 3. Save to Firestore
      await docRef.set(classData);

      _isLoading = false;
      notifyListeners();

      // 4. Show success and go back
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class created successfully!')),
        );
        Navigator.pop(context); // Go back to the dashboard
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating class: $e')));
      }
    }
  }

  Future<void> uploadMaterial({
    required String subjectId,
    required String title,
    required String type,
    required PlatformFile file,
    DateTime? deadline,
    required BuildContext context,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('materials')
          .child(subjectId)
          .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');

      UploadTask uploadTask = storageRef.putFile(File(file.path!));

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // 3. Get the Download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Save Metadata to Firestore
      // We add it to a subcollection 'materials' inside the subject
      await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectId)
          .collection('materials')
          .add({
            'title': title,
            'type': type,
            'fileUrl': downloadUrl,
            'fileName': file.name,
            'fileExtension': file.extension,
            'deadline': deadline, // Nullable
            'uploadedAt': DateTime.now(),
          });

      // 5. Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material Posted Successfully!')),
      );
      Navigator.pop(context); // Close the screen
    } catch (e) {
      print("Error uploading: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload Failed: $e')));
    }

    _isLoading = false;
    notifyListeners();
  }
}
