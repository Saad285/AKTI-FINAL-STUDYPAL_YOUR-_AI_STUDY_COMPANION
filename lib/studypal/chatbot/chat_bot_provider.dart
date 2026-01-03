import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subject_model.dart';

class ChatBotProvider extends ChangeNotifier {
  final List<String> _messages = [];
  List<String> get messages => _messages;

  // Save message to Firestore.
  // - If `subject` is provided, saves under: subjects/<subjectId>/chatbot_messages
  // - Else if user is logged in, saves under: users/<uid>/chatbot_messages
  // - Else saves under: chatbot_messages
  Future<void> addMessage(String message, {SubjectModel? subject}) async {
    _messages.add(message);
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    final CollectionReference<Map<String, dynamic>> collection;
    if (subject != null) {
      collection = FirebaseFirestore.instance
          .collection('subjects')
          .doc(subject.id)
          .collection('chatbot_messages');
    } else if (uid != null) {
      collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chatbot_messages');
    } else {
      collection = FirebaseFirestore.instance.collection('chatbot_messages');
    }

    await collection.add({
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      if (uid != null) 'userId': uid,
      if (subject != null) 'subjectId': subject.id,
      if (subject != null) 'subjectName': subject.subjectName,
    });
  }
}
