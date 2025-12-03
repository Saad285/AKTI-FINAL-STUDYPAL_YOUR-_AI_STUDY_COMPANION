import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'chat_models.dart';

class ChatDetailScreen extends StatefulWidget {
  final InboxItem user;

  const ChatDetailScreen({super.key, required this.user});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  late String chatRoomId;

  @override
  void initState() {
    super.initState();
    chatRoomId = _getChatRoomId(myUid, widget.user.id);
  }

  String _getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join("_");
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String msg = _messageController.text.trim();
    _messageController.clear();

    final timestamp = FieldValue.serverTimestamp();

    try {
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
            'content': msg,
            'senderId': myUid,
            'timestamp': timestamp,
            'isRead': false,
          });

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .set({
            'lastMessage': msg,
            'lastMessageTime': timestamp,
            'users': [myUid, widget.user.id],

            // <--- NEW: Save who sent the last message and that it is unread
            'lastSenderId': myUid,
            'isRead': false,
          }, SetOptions(merge: true));

      // 3. CRITICAL: Update 'lastActive' on BOTH User Profiles
      // This forces the Messages List to move this chat to the TOP
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'lastActive': timestamp,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({'lastActive': timestamp});
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.user.imageUrl != null
                  ? NetworkImage(widget.user.imageUrl!)
                  : null,
              child: widget.user.imageUrl == null
                  ? Text(widget.user.name[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.user.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Say hi to ${widget.user.name}!",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true, // Newest at bottom
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == myUid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: isMe
                                ? const Radius.circular(15)
                                : Radius.zero,
                            bottomRight: isMe
                                ? Radius.zero
                                : const Radius.circular(15),
                          ),
                        ),
                        child: Text(
                          data['content'] ?? "",
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      fillColor: Colors.grey[100],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
