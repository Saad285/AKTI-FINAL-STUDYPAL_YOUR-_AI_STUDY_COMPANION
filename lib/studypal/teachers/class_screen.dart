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
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        setState(() {
          currentTeacherName =
              (doc.data() as Map<String, dynamic>)['name'] ?? "Teacher";
        });
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _codeController.clear();
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
  }

  // Helper to show the dialog
  void _showScheduleDialog(String classId, String subjectName) {
    showDialog(
      context: context,
      builder: (context) =>
          AddScheduleDialog(classId: classId, subjectName: subjectName),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to get the updated list of classes
    final teacherProvider = Provider.of<TeacherProvider>(context);

    bool isButtonEnabled =
        !teacherProvider.isLoading && currentTeacherName != "Loading...";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Manage Classes",
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
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
                // --- SECTION 1: CREATE CLASS FORM ---
                Text(
                  "Create New Class",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  "Create a class first, then add a schedule to it.",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20.h),

                _buildTextField(
                  controller: TextEditingController(text: currentTeacherName),
                  label: "Instructor",
                  icon: Icons.person_outline,
                  readOnly: true,
                ),
                SizedBox(height: 20.h),
                _buildTextField(
                  controller: _nameController,
                  label: "Subject Name",
                  hint: "e.g., Linear Algebra",
                  icon: Icons.book_outlined,
                ),
                SizedBox(height: 20.h),
                _buildTextField(
                  controller: _codeController,
                  label: "Subject Code",
                  hint: "e.g., CS-201",
                  icon: Icons.qr_code_2,
                ),

                SizedBox(height: 30.h),

                // Create Button
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
                              if (success) {
                                _clearForm(); // Clear fields on success
                              }
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                      elevation: 5,
                    ),
                    child: teacherProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Create Class",
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 40.h),
                const Divider(),
                SizedBox(height: 20.h),

                // --- SECTION 2: LIST OF CREATED CLASSES ---
                Text(
                  "Classes Created This Session",
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 10.h),

                if (teacherProvider.classes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "No classes created yet.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teacherProvider.classes.length,
                    itemBuilder: (context, index) {
                      final classItem = teacherProvider.classes[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.class_,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            classItem['subjectName'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(classItem['subjectCode']),
                          trailing: OutlinedButton.icon(
                            onPressed: () => _showScheduleDialog(
                              classItem['classId'],
                              classItem['subjectName'],
                            ),
                            icon: const Icon(Icons.add_alarm, size: 18),
                            label: const Text("Schedule"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.poppins(fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
            prefixIcon: Icon(
              icon,
              color: readOnly ? Colors.grey : AppColors.primary,
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(
              vertical: 18.h,
              horizontal: 20.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
