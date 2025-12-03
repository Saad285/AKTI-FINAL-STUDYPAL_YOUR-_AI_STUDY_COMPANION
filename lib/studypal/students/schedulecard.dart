import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'dart:math';

// Note: ScheduleCard class requires getRandomColor to be defined.
// We are defining the utility function here for this single file to run
// (assuming AppColors.aestheticColors is defined elsewhere).

final _random = Random();
Color getRandomColor() {
  // Using a fallback for demonstration, as aestheticColors is in another file
  // In a real project, this function should be external in dashboard_helpers.dart
  if (AppColors.aestheticColors.isEmpty) {
    return const Color(0xFF757BC8); // Fallback color
  }
  return AppColors.aestheticColors[_random.nextInt(
    AppColors.aestheticColors.length,
  )];
}

class ScheduleCard extends StatelessWidget {
  final String subject;
  final String details;
  final String startTime;
  // EndTime removed as per user request
  final bool isOnline;
  final VoidCallback? onTap;

  const ScheduleCard({
    super.key,
    required this.subject,
    required this.details,
    required this.startTime,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Random color applied for aesthetics
    Color cardColor = getRandomColor().withOpacity(0.85);

    return GestureDetector(
      onTap: onTap, // Card is clickable only if onTap is provided (not null)
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cardColor, // Random Color applied
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Time Display (Top Row - Only Start Time)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startTime, // Only Start Time is displayed
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // 2. Subject and Status (Bottom Row)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      details,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),

                // Status Badge (Online/Notification)
                isOnline
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          'Online',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 28.sp,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
