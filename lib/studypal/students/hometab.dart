import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gcr/studypal/common/classes_list_screen.dart';
import 'package:gcr/studypal/common/today_schedule_widget.dart';
import 'package:gcr/studypal/messages/unread_chats_card.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:gcr/studypal/students/buildinfocard.dart';

class Hometab extends StatefulWidget {
  const Hometab({super.key, this.onNavigateToTab});

  final Function(int)? onNavigateToTab;

  @override
  State<Hometab> createState() => _HometabState();
}

class _HometabState extends State<Hometab> {
  late Future<DocumentSnapshot?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<DocumentSnapshot?> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      return await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Failed to load user data'),
          );
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout loading user data: $e');
      return null;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      return null;
    }
  }

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // The StreamBuilder in main.dart will automatically navigate to LoginScreen
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  void _showJoinClassDialog(BuildContext parentContext) {
    final TextEditingController codeController = TextEditingController();
    final messenger = ScaffoldMessenger.of(parentContext);

    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(parentContext).size.width * 0.85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppColors.primary.withOpacity(0.02)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.class_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Class',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect with your teacher',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enter the class code provided by your teacher',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: codeController,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Class Code',
                            hintText: 'ABC123',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade400,
                              letterSpacing: 2,
                            ),
                            labelStyle: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.vpn_key_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(context).pop();
                                codeController.dispose();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final code = codeController.text
                                    .trim()
                                    .toUpperCase();
                                if (code.isEmpty) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: const [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Please enter a class code'),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  // Search for class with the code
                                  final classQuery = await FirebaseFirestore
                                      .instance
                                      .collection('classes')
                                      .where('subjectCode', isEqualTo: code)
                                      .limit(1)
                                      .get()
                                      .timeout(const Duration(seconds: 10));

                                  if (classQuery.docs.isEmpty) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(
                                              Icons.cancel_outlined,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 12),
                                            Text('Invalid class code'),
                                          ],
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final classDoc = classQuery.docs.first;
                                  final userId =
                                      FirebaseAuth.instance.currentUser?.uid;

                                  if (userId == null) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Please sign in to join a class.',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  await classDoc.reference.update({
                                    'students': FieldValue.arrayUnion([userId]),
                                  });

                                  // Close dialog immediately
                                  if (context.mounted) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    Navigator.of(context).pop();
                                  }

                                  // Dispose controller after navigation completes
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      codeController.dispose();
                                    },
                                  );

                                  // Navigate to classes tab first
                                  widget.onNavigateToTab?.call(4);

                                  // Add student to all schedules for this class in background
                                  // This is non-blocking and won't freeze the UI
                                  FirebaseFirestore.instance
                                      .collection('schedules')
                                      .where('classId', isEqualTo: classDoc.id)
                                      .get()
                                      .timeout(const Duration(seconds: 5))
                                      .then((schedules) {
                                        for (var scheduleDoc
                                            in schedules.docs) {
                                          scheduleDoc.reference
                                              .update({
                                                'students':
                                                    FieldValue.arrayUnion([
                                                      userId,
                                                    ]),
                                              })
                                              .catchError((e) {
                                                debugPrint(
                                                  '⚠️ Failed to update schedule ${scheduleDoc.id}: $e',
                                                );
                                              });
                                        }
                                        debugPrint(
                                          '✅ Added student to ${schedules.docs.length} schedules',
                                        );
                                      })
                                      .catchError((e) {
                                        debugPrint(
                                          '⚠️ Failed to add student to schedules: $e',
                                        );
                                      });

                                  // Show success message
                                  if (parentContext.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Successfully joined ${classDoc['subjectName']}!',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.green.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  debugPrint('\u274c Join class error: $e');

                                  String errorMessage = 'Failed to join class.';

                                  if (e is FirebaseException) {
                                    switch (e.code) {
                                      case 'permission-denied':
                                        errorMessage =
                                            'Permission denied. Check Firestore rules.';
                                        break;
                                      case 'unavailable':
                                        errorMessage =
                                            'Network error. Check your connection.';
                                        break;
                                      case 'not-found':
                                        errorMessage = 'Class not found.';
                                        break;
                                      default:
                                        errorMessage =
                                            'Error: ${e.message ?? "Unknown error"}';
                                    }
                                  } else if (e.toString().contains('network')) {
                                    errorMessage =
                                        'Network error. Please check your internet connection.';
                                  }

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(errorMessage)),
                                        ],
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.login_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Join Class',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String userName, String userEmail) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.primary.withOpacity(0.05)],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 200.h,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    userName.replaceFirst('Hello ', ''),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    userEmail,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            _buildDrawerItem(
              context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Settings coming soon',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.help_rounded,
              title: 'Help & Support',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Help coming soon',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.info_rounded,
              title: 'About',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.school_rounded, color: AppColors.primary),
                        SizedBox(width: 12.w),
                        Text(
                          'StudyPal',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      'StudyPal - Your Personal Study Assistant\n\nVersion 1.0.0',
                      style: GoogleFonts.poppins(fontSize: 14.sp),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(height: 32.h, thickness: 1, indent: 16.w, endIndent: 16.w),
            _buildDrawerItem(
              context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              iconColor: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.delete_forever_rounded,
              title: 'Delete Account',
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22.sp),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28.sp),
            SizedBox(width: 12.w),
            Text(
              'Delete Account?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Please log out and log in again before deleting account.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Unable to delete account: ${e.message}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete account. Please re-auth and retry.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color infoTextColor = Colors.white;

    return FutureBuilder<DocumentSnapshot?>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        debugPrint(
          'HOMETAB: state=${snapshot.connectionState}, hasData=${snapshot.hasData}, error=${snapshot.error}',
        );

        String userName = "Loading...";
        bool isTeacher = false;
        final User? user = FirebaseAuth.instance.currentUser;

        // On app restart/hot restart FirebaseAuth may not have restored the user yet.
        // Avoid building Firestore queries with null uid (can crash).
        if (user == null) {
          debugPrint('HOMETAB: user is null, showing loading');
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final String userId =
            user.uid; // Store uid to prevent null issues later

        // Show loading while waiting for Firestore
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('HOMETAB: showing loading state');
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle error state
        if (snapshot.hasError) {
          debugPrint('HOMETAB: Error loading user data: ${snapshot.error}');
          userName = "Hello ${user.email?.split('@')[0] ?? 'User'}";
          isTeacher = true;
        }
        // If snapshot has data and document exists, use the name from Firestore
        else if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          userName = "Hello ${data['name'] ?? 'User'}";
          final role = data['role'];
          isTeacher =
              role != null && role.toString().toLowerCase() == 'teacher';
        } else if (snapshot.connectionState == ConnectionState.done) {
          // If loading is done but no document exists, create it as teacher and use email as fallback
          userName = "Hello ${user.email?.split('@')[0] ?? 'User'}";
          isTeacher = true; // Default to teacher when no document exists

          // Auto-create the missing Firestore document
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({
                'uid': userId,
                'email': user.email,
                'name': user.email?.split('@')[0] ?? 'User',
                'role': 'teacher',
              })
              .then((_) {
                debugPrint('✅ Created missing user document as teacher');
                if (mounted) {
                  setState(() {
                    _userDataFuture = _fetchUserData();
                  });
                }
              })
              .catchError((e) {
                debugPrint('❌ Failed to create user document: $e');
              });
        }

        return Scaffold(
          backgroundColor: Colors.white,
          drawer: _buildDrawer(context, userName, user.email ?? ''),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            title: Text(
              'StudyPal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20.sp,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- HEADER ----------
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 30.h),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(-20 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          userName,
                          style: GoogleFonts.poppins(
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(-20 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          'Role: ${isTeacher ? 'Teacher' : 'Student'}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30.h),

                // ---------- CONTENT ----------
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          "My Dashboard",
                          style: GoogleFonts.poppins(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),

                      // --- ROW 1: ACTIVE CLASSES & PENDING ---
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(-30 * (1 - value), 0),
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            // 1. ACTIVE CLASSES CARD (With StreamBuilder)
                            isTeacher
                                ? StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('classes')
                                        .where('teacherId', isEqualTo: userId)
                                        .snapshots(),
                                    builder: (context, classSnapshot) {
                                      String count = "0";
                                      if (classSnapshot.hasData) {
                                        count = classSnapshot.data!.docs.length
                                            .toString();
                                      }
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ClassesListScreen(),
                                            ),
                                          );
                                        },
                                        child: IinfoCard(
                                          title: "Active",
                                          number: count,
                                          subtitle: "classes",
                                          bgColor: const Color(0xFF757BC8),
                                          textColor: infoTextColor,
                                          width: 120,
                                        ),
                                      );
                                    },
                                  )
                                : StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('classes')
                                        .where(
                                          'students',
                                          arrayContains: userId,
                                        )
                                        .snapshots(),
                                    builder: (context, classSnapshot) {
                                      final joinedCount = classSnapshot.hasData
                                          ? classSnapshot.data!.docs.length
                                                .toString()
                                          : "0";
                                      return GestureDetector(
                                        onTap: () {
                                          // Navigate to classes tab (index 4)
                                          widget.onNavigateToTab?.call(4);
                                        },
                                        child: IinfoCard(
                                          title: "Joined",
                                          number: joinedCount,
                                          subtitle: "classes",
                                          bgColor: const Color(0xFF757BC8),
                                          textColor: infoTextColor,
                                          width: 120,
                                        ),
                                      );
                                    },
                                  ),

                            SizedBox(width: 14.w),

                            // 2. REMINDERS DUE TODAY CARD
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('reminders')
                                    .where('userId', isEqualTo: userId)
                                    .snapshots(),
                                builder: (context, reminderSnapshot) {
                                  // Filter reminders for today
                                  final today = DateTime.now();
                                  final startOfDay = DateTime(
                                    today.year,
                                    today.month,
                                    today.day,
                                  );
                                  final endOfDay = DateTime(
                                    today.year,
                                    today.month,
                                    today.day,
                                    23,
                                    59,
                                    59,
                                  );

                                  final todayReminders =
                                      reminderSnapshot.hasData
                                      ? reminderSnapshot.data!.docs
                                            .where((doc) {
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              final date =
                                                  (data['date'] as Timestamp)
                                                      .toDate();
                                              final completed =
                                                  data['completed'] as bool? ??
                                                  false;
                                              return !completed &&
                                                  date.isAfter(startOfDay) &&
                                                  date.isBefore(endOfDay);
                                            })
                                            .toList()
                                            .cast<QueryDocumentSnapshot>()
                                      : <QueryDocumentSnapshot>[];

                                  return GestureDetector(
                                    onTap: () {
                                      // Show dialog with today's reminders
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            _RemindersDueTodayDialog(
                                              reminders: todayReminders,
                                              userId: userId,
                                            ),
                                      );
                                    },
                                    child: Container(
                                      height: 130.h,
                                      padding: EdgeInsets.all(16.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB13D),
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFFB13D,
                                            ).withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Reminders",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w500,
                                              color: infoTextColor.withAlpha(
                                                (255 * 0.9).round(),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 5.h),
                                          Text(
                                            todayReminders.length.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 32.sp,
                                              fontWeight: FontWeight.bold,
                                              color: infoTextColor,
                                            ),
                                          ),
                                          Text(
                                            "today",
                                            style: GoogleFonts.poppins(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w400,
                                              color: infoTextColor.withAlpha(
                                                (255 * 0.9).round(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // --- ROW 2: CREATE/NEW & MESSAGES ---
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(-30 * (1 - value), 0),
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (isTeacher) {
                                    // Navigate to classes tab for teachers
                                    widget.onNavigateToTab?.call(4);
                                  } else {
                                    // Show Join Class Dialog for students
                                    _showJoinClassDialog(context);
                                  }
                                },
                                child: IinfoCard(
                                  title: "Create",
                                  number: "+",
                                  subtitle: "new class",
                                  bgColor: AppColors.primary,
                                  textColor: infoTextColor,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            SizedBox(width: 14.w),

                            // 4. MESSAGES CARD
                            UnreadChatsCard(
                              onTap: () {
                                // Navigate to messages tab (index 1)
                                widget.onNavigateToTab?.call(1);
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30.h),

                      // --- TODAY SCHEDULE ---
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          "Today's schedule",
                          style: GoogleFonts.poppins(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: const TodayScheduleWidget(),
                      ),

                      SizedBox(height: 120.h),
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

// Dialog to show reminders due today with checkboxes
class _RemindersDueTodayDialog extends StatelessWidget {
  const _RemindersDueTodayDialog({
    required this.reminders,
    required this.userId,
  });

  final List<QueryDocumentSnapshot> reminders;
  final String userId;

  Future<void> _toggleReminderComplete(
    String reminderId,
    bool currentState,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .update({'completed': !currentState});
    } catch (e) {
      debugPrint("Error updating reminder: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 500.h, maxWidth: 400.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.today_rounded, color: Colors.white, size: 28.sp),
                  SizedBox(width: 12.w),
                  Text(
                    "Reminders Due Today",
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Reminder List
            Flexible(
              child: reminders.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(40.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64.sp,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            "No reminders due today!",
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      itemCount: reminders.length,
                      itemBuilder: (context, index) {
                        final doc = reminders[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] as String? ?? 'Untitled';
                        final completed = data['completed'] as bool? ?? false;
                        final type = data['type'] as String? ?? 'note';

                        // Icon based on type
                        IconData typeIcon;
                        Color typeColor;
                        switch (type) {
                          case 'assignment':
                            typeIcon = Icons.assignment_rounded;
                            typeColor = Colors.orange;
                            break;
                          case 'quiz':
                            typeIcon = Icons.quiz_rounded;
                            typeColor = Colors.purple;
                            break;
                          default:
                            typeIcon = Icons.note_rounded;
                            typeColor = Colors.blue;
                        }

                        return InkWell(
                          onTap: () =>
                              _toggleReminderComplete(doc.id, completed),
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.h,
                            ),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: completed
                                  ? Colors.grey[100]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: completed
                                    ? Colors.grey[300]!
                                    : AppColors.primary.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                Container(
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? AppColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(
                                      color: completed
                                          ? AppColors.primary
                                          : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: completed
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16.sp,
                                        )
                                      : null,
                                ),
                                SizedBox(width: 12.w),

                                // Type Icon
                                Icon(
                                  typeIcon,
                                  size: 20.sp,
                                  color: completed
                                      ? Colors.grey[400]
                                      : typeColor,
                                ),
                                SizedBox(width: 12.w),

                                // Title
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: completed
                                          ? Colors.grey[500]
                                          : Colors.black87,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Close Button
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
