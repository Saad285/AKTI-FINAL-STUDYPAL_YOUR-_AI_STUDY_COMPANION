import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class IinfoCard extends StatelessWidget {
  final String title;
  final String number;
  final String subtitle;
  final Color bgColor;
  final Color textColor;
  final double width;

  const IinfoCard({
    super.key,
    required this.title,
    required this.number,
    required this.subtitle,
    required this.bgColor,
    required this.textColor,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate alpha value for 90% opacity (Non-deprecated method)
    final Color subduedTextColor = textColor.withAlpha((255 * 0.9).round());

    return Container(
      width: width.w,
      height: 130.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
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
    );
  }
}
