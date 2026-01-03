import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// For clipboard
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TodayScheduleWidget extends StatelessWidget {
  const TodayScheduleWidget({super.key});

  String _getCurrentDay() {
    return DateFormat(
      'EEEE',
    ).format(DateTime.now()); // Returns "Monday", "Tuesday", etc.
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final currentDay = _getCurrentDay();

    // Avoid running Firestore queries with null userId during app restart.
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('teacherId', isEqualTo: userId)
          .where('day', isEqualTo: currentDay)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              height: 20.h,
              width: 20.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // 2. Error State (Likely Missing Index)
        if (snapshot.hasError) {
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Text(
                  "Database Error (Missing Index)",
                  style: GoogleFonts.poppins(
                    color: Colors.red[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Check your Debug Console in VS Code. Click the link starting with 'https://console.firebase...' to create the required index.",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.red[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 3. Empty State (No classes for TODAY)
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 25.h, horizontal: 20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF404040).withValues(alpha: 0.05),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 40.sp,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 10.h),
                Text(
                  "No classes scheduled for $currentDay",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // 4. Success State (List of Schedules)
        final schedules = snapshot.data!.docs;

        return Column(
          children: schedules.asMap().entries.map((entry) {
            final idx = entry.key;
            final doc = entry.value;
            final data = doc.data() as Map<String, dynamic>;

            final isOnline = data['type'] == 'Online';

            // Use random aesthetic color for each card
            Color cardColor = AppColors.randomAesthetic(idx);

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: cardColor, // Using the beautiful colors
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withValues(alpha: 0.4),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // --- ICON CONTAINER ---
                  Container(
                    height: 50.w,
                    width: 50.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),

                  // --- TEXT CONTENT ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject Name
                        Text(
                          data['subjectName'] ?? 'Subject',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.h),

                        // Time & Type
                        Row(
                          children: [
                            Text(
                              "${data['time']}",
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: Icon(
                                Icons.circle,
                                size: 4.sp,
                                color: Colors.white54,
                              ),
                            ),
                            Text(
                              data['type'] ?? 'On Campus',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),

                        // Location (Room or Link)
                        Row(
                          children: [
                            Icon(
                              isOnline ? Icons.link : Icons.location_on_rounded,
                              size: 14.sp,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                isOnline
                                    ? (data['classLink'] ?? 'No Link')
                                    : "Room: ${data['roomNumber'] ?? 'N/A'}",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
