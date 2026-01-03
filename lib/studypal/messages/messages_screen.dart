import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Models/chat_models.dart';
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

  late Stream<QuerySnapshot> _teacherStream;
  late Stream<QuerySnapshot> _studentStream;

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
    final ids = [user1, user2]..sort();
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
                final collection = FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .collection('messages');
                final snapshots = await collection.get();
                for (final doc in snapshots.docs) {
                  await doc.reference.delete();
                }
                await FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .delete();

                if (!mounted || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Chat deleted successfully")),
                );
              } catch (e) {
                if (!mounted || !context.mounted) return;
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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: _updateSearch,
                  style: GoogleFonts.poppins(color: Colors.white),
                  cursorColor: Colors.white,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search user...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  "Messages",
                  style: GoogleFonts.poppins(
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
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: const [
              Tab(text: "Teachers"),
              Tab(text: "Students"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFirestoreList(_teacherStream),
            _buildFirestoreList(_studentStream),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreList(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        final List<InboxItem> users = [];
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (doc.id == myUid) continue;

          final name = (data['name'] ?? '').toString();
          if (_searchKeyword.isNotEmpty &&
              !name.toLowerCase().contains(_searchKeyword)) {
            continue;
          }

          users.add(
            InboxItem(
              id: doc.id,
              name: name.isEmpty ? 'Unknown' : name,
              imageUrl: data['imageUrl'],
              role: data['role'] ?? '',
            ),
          );
        }

        if (users.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final item = users[index];
            return _InboxCard(
              item: item,
              myUid: myUid,
              isSearching: _isSearching,
              getChatRoomId: _getChatRoomId,
              onDelete: _deleteChatConfirmation,
            );
          },
        );
      },
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.item,
    required this.myUid,
    required this.isSearching,
    required this.getChatRoomId,
    required this.onDelete,
  });

  final InboxItem item;
  final String myUid;
  final bool isSearching;
  final String Function(String, String) getChatRoomId;
  final Future<void> Function(BuildContext, String, String) onDelete;

  @override
  Widget build(BuildContext context) {
    final String chatRoomId = getChatRoomId(myUid, item.id);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final bool hasMessages =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        if (!isSearching && !hasMessages) {
          return const SizedBox.shrink();
        }

        String content = "Start a conversation";
        String senderId = "";
        bool isRead = true;
        Timestamp? t;

        if (hasMessages) {
          try {
            final data =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            content = data['content'] ?? "Sent a file";
            senderId = data['senderId'] ?? "";
            isRead = data['isRead'] ?? true;
            t = data['timestamp'];
          } catch (_) {
            content = "Unable to load message";
          }
        }

        final bool isUnseen = senderId != myUid && !isRead;
        final String lastMessage = senderId == myUid
            ? "You: $content"
            : content;

        String time = "";
        if (t != null) {
          try {
            final date = t.toDate();
            final hour = date.hour;
            final displayHour = hour > 12
                ? hour - 12
                : hour == 0
                ? 12
                : hour;
            time =
                "$displayHour:${date.minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}";
          } catch (_) {
            time = "";
          }
        }

        return GestureDetector(
          onTap: () {
            try {
              FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .set({'isRead': true}, SetOptions(merge: true));

              if (isUnseen && hasMessages && snapshot.data!.docs.isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(chatRoomId)
                    .collection('messages')
                    .doc(snapshot.data!.docs.first.id)
                    .update({'isRead': true})
                    .catchError(
                      (error) =>
                          debugPrint('Failed to mark message read: $error'),
                    );
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(user: item),
                ),
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
          onLongPress: () => onDelete(context, chatRoomId, item.name),
          child:
              Container(
                    margin: EdgeInsets.only(bottom: 15.h),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.black, width: 2.w),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Hero(
                              tag: 'avatar_${item.id}',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 30.r,
                                  backgroundColor: AppColors.primary,
                                  child:
                                      item.imageUrl != null &&
                                          item.imageUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: item.imageUrl!,
                                            width: 60.w,
                                            height: 60.w,
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            placeholder: (context, url) => SizedBox(
                                              width: 24.w,
                                              height: 24.w,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 28.w,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          item.name.isNotEmpty
                                              ? item.name[0].toUpperCase()
                                              : "?",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 24.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (isUnseen)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 18.w,
                                  height: 18.w,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3.w,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 15.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: isUnseen
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                        fontSize: 16.sp,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (time.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUnseen
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.sp,
                                          color: isUnseen
                                              ? Colors.blue
                                              : Colors.grey[600],
                                          fontWeight: isUnseen
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                lastMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: !hasMessages
                                      ? AppColors.primary
                                      : (isUnseen
                                            ? Colors.black87
                                            : Colors.grey[600]),
                                  fontStyle: !hasMessages
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  fontWeight: isUnseen
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black54,
                          size: 24.sp,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
                  .slideX(
                    begin: 0.15,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),
        );
      },
    );
  }
}
