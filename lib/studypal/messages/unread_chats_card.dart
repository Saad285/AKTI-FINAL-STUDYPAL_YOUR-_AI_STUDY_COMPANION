import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Import
import 'package:firebase_auth/firebase_auth.dart'; // Auth Import

class UnreadChatsCard extends StatelessWidget {
  const UnreadChatsCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // Avoid Firestore query crashes (arrayContains cannot be null).
    if (myUid == null || myUid.isEmpty) {
      return InfoCard(
        title: "New",
        number: "0",
        subtitle: "messages",
        bgColor: const Color(0xFF757BC8),
        textColor: Colors.white,
        width: 120,
        onTap: onTap,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('users', arrayContains: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        String countDisplay = "0";

        if (snapshot.hasData) {
          // Logic: Count chats that are NOT read AND I am NOT the sender
          int unreadCount = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool isRead = data['isRead'] ?? true;
            String senderId = data['lastSenderId'] ?? "";

            return !isRead && senderId != myUid;
          }).length;

          countDisplay = unreadCount.toString();
        }

        // Return the UI with the dynamic number
        return InfoCard(
          title: "New",
          number: countDisplay,
          subtitle: "messages",
          bgColor: const Color(0xFF757BC8),
          textColor: Colors.white,
          width: 120,
          onTap: onTap,
        );
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String number;
  final String subtitle;
  final Color bgColor;
  final Color textColor;
  final double width;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.title,
    required this.number,
    required this.subtitle,
    required this.bgColor,
    required this.textColor,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color subduedTextColor = textColor.withAlpha((255 * 0.9).round());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width.w,
        height: 130.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: subduedTextColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              number,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: subduedTextColor,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
