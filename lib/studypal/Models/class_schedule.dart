import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSchedule {
  final String id;
  final String classId;
  final String teacherId;
  final String day; // e.g., "Monday"
  final String time; // e.g., "10:00 AM"
  final String subjectName;
  final String type; // "On Campus" or "Online"
  final String roomNumber; // Optional (if On Campus)
  final String classLink; // Optional (if Online)
  final DateTime createdAt;

  ClassSchedule({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.day,
    required this.time,
    required this.subjectName,
    required this.type,
    this.roomNumber = '',
    this.classLink = '',
    required this.createdAt,
  });

  // Convert from Firestore Document
  factory ClassSchedule.fromMap(Map<String, dynamic> data, String documentId) {
    return ClassSchedule(
      id: documentId,
      classId: data['classId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      day: data['day'] ?? '',
      time: data['time'] ?? '',
      subjectName: data['subjectName'] ?? '',
      type: data['type'] ?? 'On Campus',
      roomNumber: data['roomNumber'] ?? '',
      classLink: data['classLink'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Map for Saving
  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'teacherId': teacherId,
      'day': day,
      'time': time,
      'subjectName': subjectName,
      'type': type,
      'roomNumber': roomNumber,
      'classLink': classLink,
      'createdAt': createdAt,
    };
  }
}
