import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Inbox Item (User in the list)
class InboxItem {
  final String id; // The UID of the other user
  final String name;
  final String? imageUrl;
  final String role; // "Student" or "Teacher"

  final bool isUnseen;

  InboxItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.role,
    this.isUnseen = false,
  });

  factory InboxItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InboxItem(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      imageUrl: data['imageUrl'],
      role: data['role'] ?? 'Student',
      isUnseen: data['isUnseen'] ?? false,
    );
  }
}

// 2. Chat Bubble Data (Single Message)
class ChatBubbleData {
  final String content;
  final bool isMe;
  final Timestamp timestamp;

  ChatBubbleData({
    required this.content,
    required this.isMe,
    required this.timestamp,
  });
}
