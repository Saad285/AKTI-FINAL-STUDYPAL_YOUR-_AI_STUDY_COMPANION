import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gcr/studypal/theme/animated_background.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'chat_models.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isSearching = false;
  String _searchKeyword = "";
  final TextEditingController _searchController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Streams declared here to prevent reloading when typing
  late Stream<QuerySnapshot> _teacherStream;
  late Stream<QuerySnapshot> _studentStream;

  final List<Color> _bgColors = [
    const Color(0xFFE0F7FA),
    AppColors.primary.withOpacity(0.2),
    const Color.fromARGB(255, 234, 234, 234),
  ];

  @override
  void initState() {
    super.initState();

    _teacherStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Teacher')
        .snapshots();

    _studentStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Student')
        .snapshots();
  }

  void _updateSearch(String value) {
    setState(() {
      _searchKeyword = value.toLowerCase();
    });
  }

  String _getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join("_");
  }

  Future<void> _deleteChatConfirmation(
    BuildContext context,
    String chatRoomId,
    String userName,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat"),
        content: Text(
          "Are you sure you want to delete the conversation with $userName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 1. Delete messages
                final collection = FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .collection('messages');
                var snapshots = await collection.get();
                for (var doc in snapshots.docs) {
                  await doc.reference.delete();
                }
                // 2. Delete room metadata (Fixes dashboard count sticking)
                await FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .delete();

                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Chat deleted successfully")),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: (value) => _updateSearch(value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search user...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                )
              : const Text(
                  "Messages",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _updateSearch("");
                  }
                });
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: "Teachers"),
              Tab(text: "Students"),
            ],
          ),
        ),
        body: AnimatedBackground(
          colors: _bgColors,
          child: TabBarView(
            children: [
              _buildFirestoreList(_teacherStream),
              _buildFirestoreList(_studentStream),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirestoreList(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text("No users found"));

        List<InboxItem> users = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'].toString().toLowerCase();
              return name.contains(_searchKeyword);
            })
            .map((doc) => InboxItem.fromFirestore(doc))
            .toList();

        if (users.isEmpty)
          return const Center(child: Text("No users match search"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildInboxCard(context, users[index]);
          },
        );
      },
    );
  }

  Widget _buildInboxCard(BuildContext context, InboxItem item) {
    final String chatRoomId = _getChatRoomId(myUid, item.id);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // Check if we have messages
        bool hasMessages = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        // LOGIC 1: If NOT searching AND No Messages -> Hide card
        if (!_isSearching && !hasMessages) {
          return const SizedBox.shrink();
        }

        // Setup variables with DEFAULTS (safe for empty chats)
        String content = "Start a conversation";
        String senderId = "";
        bool isRead = true;
        Timestamp? t;

        // Only overwrite if data exists
        if (hasMessages) {
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          content = data['content'] ?? "Sent a file";
          senderId = data['senderId'] ?? "";
          isRead = data['isRead'] ?? true;
          t = data['timestamp'];
        }

        String lastMessage = "";
        String time = "";
        bool isUnseen = false;

        // Check Unseen
        if (senderId != myUid && !isRead) {
          isUnseen = true;
        }

        // Format Message
        if (senderId == myUid) {
          lastMessage = "You: $content";
        } else {
          lastMessage = content;
        }

        // Format Time
        if (t != null) {
          DateTime date = t.toDate();
          time =
              "${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
        }

        return GestureDetector(
          onTap: () {
            // LOGIC 2: Force Dashboard Update (Always mark room as read)
            FirebaseFirestore.instance
                .collection('chat_rooms')
                .doc(chatRoomId)
                .update({'isRead': true});

            // Mark specific message read (Blue Dot)
            if (isUnseen && hasMessages) {
              FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .doc(snapshot.data!.docs.first.id)
                  .update({'isRead': true});
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(user: item),
              ),
            );
          },
          onLongPress: () {
            _deleteChatConfirmation(context, chatRoomId, item.name);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isUnseen
                  ? const Color(0xFFE3F2FD)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUnseen
                    ? Colors.blue
                    : const Color(0xFF7B7DBC).withOpacity(0.3),
                width: isUnseen ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF7B7DBC),
                      backgroundImage: item.imageUrl != null
                          ? NetworkImage(item.imageUrl!)
                          : null,
                      child: item.imageUrl == null
                          ? Text(
                              item.name.isNotEmpty
                                  ? item.name[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (isUnseen)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: isUnseen
                                  ? FontWeight.w900
                                  : FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnseen ? Colors.blue : Colors.grey[500],
                              fontWeight: isUnseen
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lastMessage,
                        style: TextStyle(
                          fontSize: 14,
                          // New Chat? Show Primary Color. Unseen? Black. Read? Grey.
                          color: !hasMessages
                              ? AppColors.primary
                              : (isUnseen ? Colors.black87 : Colors.grey[600]),
                          fontStyle: !hasMessages
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: isUnseen
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
