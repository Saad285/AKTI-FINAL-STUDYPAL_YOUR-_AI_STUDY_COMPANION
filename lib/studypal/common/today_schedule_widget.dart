import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Ensure ScreenUtil is imported
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TodayScheduleWidget extends StatelessWidget {
  const TodayScheduleWidget({super.key});

  String _getCurrentDay() {
    return DateFormat('EEEE').format(DateTime.now()); // e.g., "Monday"
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final currentDay = _getCurrentDay();

    // Avoid running Firestore queries with null userId during app restart.
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              height: 20.h,
              width: 20.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final isTeacher =
            userSnapshot.hasData &&
            userSnapshot.data != null &&
            userSnapshot.data!.exists &&
            (userSnapshot.data!.data() as Map<String, dynamic>?)?['role']
                    ?.toString()
                    .toLowerCase() ==
                'teacher';

        return StreamBuilder<QuerySnapshot>(
          stream: isTeacher
              ? FirebaseFirestore.instance
                    .collection('schedules')
                    .where('teacherId', isEqualTo: userId)
                    .where('day', isEqualTo: currentDay)
                    .snapshots()
              : FirebaseFirestore.instance
                    .collection('schedules')
                    .where('students', arrayContains: userId)
                    .where('day', isEqualTo: currentDay)
                    .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              // Empty State - Matching App Aesthetic
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 25.h, horizontal: 20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF404040).withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 40.sp,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "No classes today",
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

            final schedules = snapshot.data!.docs;

            return Column(
              children: schedules.asMap().entries.map((entry) {
                final idx = entry.key;
                final doc = entry.value;
                final data = doc.data() as Map<String, dynamic>;

                // Determine Icon based on Type
                final isOnline = data['type'] == 'Online';

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.randomAesthetic(idx).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF404040).withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
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
                          color: Colors.white.withOpacity(0.12),
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
                                    color: Colors.white70,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                  ),
                                  child: Icon(
                                    Icons.circle,
                                    size: 4.sp,
                                    color: Colors.white24,
                                  ),
                                ),
                                Text(
                                  data['type'] ?? 'On Campus',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12.sp,
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
                                  isOnline
                                      ? Icons.link
                                      : Icons.location_on_outlined,
                                  size: 14.sp,
                                  color: Colors.white,
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
      },
    );
  }
}
