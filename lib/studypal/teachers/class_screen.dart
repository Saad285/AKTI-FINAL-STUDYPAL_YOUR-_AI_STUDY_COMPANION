import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/providers/teacher_provider.dart';
import 'package:gcr/studypal/teachers/add_schedule_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String currentTeacherName = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchTeacherName();
  }

  Future<void> _fetchTeacherName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            currentTeacherName = "Guest";
          });
        }
        return;
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Failed to load teacher data'),
          );

      if (mounted && doc.exists) {
        setState(() {
          currentTeacherName =
              (doc.data() as Map<String, dynamic>)['name'] ?? "Teacher";
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout loading teacher name: $e');
      if (mounted) {
        setState(() {
          currentTeacherName = "Teacher";
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          currentTeacherName = "Teacher";
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching teacher name: $e');
      if (mounted) {
        setState(() {
          currentTeacherName = "Teacher";
        });
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _codeController.clear();
    FocusScope.of(context).unfocus();
  }

  void _showScheduleDialog(String classId, String subjectName) {
    showDialog(
      context: context,
      builder: (context) =>
          AddScheduleDialog(classId: classId, subjectName: subjectName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherProvider = Provider.of<TeacherProvider>(context);
    bool isButtonEnabled =
        !teacherProvider.isLoading && currentTeacherName != "Loading...";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50], // Soft grey background
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          // --- 1. Curved Header ---
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
          ),
          toolbarHeight: 70.h,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Manage Classes",
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1: INSTRUCTOR BADGE ---
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 20.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "Instructor: $currentTeacherName",
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 30.h),

                // --- SECTION 2: INPUT FORM ---
                Text(
                  "Create New Class",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  "Enter the subject details below.",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 20.h),

                _buildStylishField(
                  controller: _nameController,
                  label: "Subject Name",
                  hint: "e.g. Linear Algebra",
                  icon: Icons.menu_book_rounded,
                ),
                SizedBox(height: 16.h),
                _buildStylishField(
                  controller: _codeController,
                  label: "Subject Code",
                  hint: "e.g. CS-201",
                  icon: Icons.qr_code_rounded,
                ),

                SizedBox(height: 30.h),

                // --- CREATE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed: isButtonEnabled
                        ? () async {
                            if (_nameController.text.isNotEmpty &&
                                _codeController.text.isNotEmpty) {
                              bool success = await teacherProvider.createClass(
                                subjectName: _nameController.text,
                                subjectCode: _codeController.text,
                                teacherName: currentTeacherName,
                                context: context,
                              );
                              if (success) _clearForm();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please fill all fields"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 8,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: teacherProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Create Class",
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 40.h),
                Divider(color: Colors.grey[200], thickness: 2),
                SizedBox(height: 20.h),

                // --- SECTION 3: RECENT CLASSES ---
                Text(
                  "Recent Classes",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 15.h),

                if (teacherProvider.classes.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 40.sp,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          "No classes created in this session.",
                          style: GoogleFonts.poppins(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teacherProvider.classes.length,
                    itemBuilder: (context, index) {
                      final classItem = teacherProvider.classes[index];
                      // Random color for the mini-icon
                      Color accentColor = AppColors.randomAesthetic(index);

                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          leading: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.class_rounded,
                              color: accentColor,
                              size: 24.sp,
                            ),
                          ),
                          title: Text(
                            classItem['subjectName'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          subtitle: Text(
                            classItem['subjectCode'],
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _showScheduleDialog(
                              classItem['classId'],
                              classItem['subjectName'],
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentColor,
                              side: BorderSide(
                                color: accentColor.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 0,
                              ),
                            ),
                            child: const Text("Schedule"),
                          ),
                        ),
                      );
                    },
                  ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- STYLISH TEXT FIELD ---
  Widget _buildStylishField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(fontSize: 15.sp, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14.sp,
              ),
              prefixIcon: Icon(icon, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 16.h,
                horizontal: 20.w,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
