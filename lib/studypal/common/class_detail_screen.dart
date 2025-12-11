import 'package:flutter/material.dart';
import 'package:gcr/studypal/Models/subject_model.dart';
import 'package:gcr/studypal/teachers/upload_material_screen.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ClassDetailScreen extends StatelessWidget {
  final SubjectModel subject;
  final bool isTeacher;

  const ClassDetailScreen({
    super.key,
    required this.subject,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    // Simulating a list for now. Later this will come from Firebase.
    final List<String> materials = [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          subject.subjectName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // ONLY Teacher sees the Edit button
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Settings logic
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Header with Code
          Container(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Text(
                  "Subject Code: ${subject.subjectCode}",
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Instructor: ${subject.teacherName}",
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Content Area (List or Empty State)
          Expanded(
            child: materials.isNotEmpty
                ? ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      // Example List Item for future use
                      return Card(
                        child: ListTile(
                          title: Text("Material $index"),
                          leading: const Icon(Icons.picture_as_pdf),
                        ),
                      );
                    },
                  )
                : Center(
                    // This centers the Empty State correctly
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.folder_open_rounded,
                            size: 60.sp,
                            color: Colors.grey[300],
                          ),
                        ),
                        SizedBox(height: 15.h),
                        Text(
                          "No materials uploaded yet",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),

      // ONLY Teacher sees the Upload button
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadMaterialScreen(
                      subjectId: subject.id,
                    ), // Pass the ID!
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              label: Text(
                "Upload Material",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
