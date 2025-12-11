import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'dart:math';

final _random = Random();

Color getRandomButtonColor() {
  return AppColors.aestheticColors[_random.nextInt(
    AppColors.aestheticColors.length,
  )];
}
// --------------------------

class ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const ActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Logic: If onTap is present, the button is enabled.
    bool isEnabled = onTap != null;

    // Randomly selected color for active state
    Color activeColor = getRandomButtonColor();

    // Choose colors based on state
    Color buttonColor = isEnabled ? activeColor : Colors.grey[400]!;
    Color textColor = isEnabled ? Colors.white : Colors.grey[700]!;

    return GestureDetector(
      // Only runs onTap if it is not null
      onTap: onTap,
      child: Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    // Shadow matches the active random color
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    // Styling for the disabled look
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
