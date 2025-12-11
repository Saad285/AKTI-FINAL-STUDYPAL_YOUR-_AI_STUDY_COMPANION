class SubjectModel {
  final String id;
  final String subjectName;
  final String subjectCode;
  final String teacherId;
  final String teacherName;

  SubjectModel({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.teacherId,
    required this.teacherName,
  });

  // Convert to Map for saving to Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectName': subjectName,
      'subjectCode': subjectCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'createdAt': DateTime.now(),
    };
  }
}
