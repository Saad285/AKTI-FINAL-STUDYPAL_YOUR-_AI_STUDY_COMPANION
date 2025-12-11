import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gcr/studypal/Models/subject_model.dart';
import 'package:gcr/studypal/teachers/class_screen.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'class_detail_screen.dart';

class ClassesListScreen extends StatelessWidget {
  const ClassesListScreen({super.key});

  // Helper to fetch user role
  Future<bool> _isTeacher() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return (doc.data() as Map<String, dynamic>)['role'] == 'Teacher';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<bool>(
      future: _isTeacher(), // Check role first
      builder: (context, roleSnapshot) {
        // Default to false while loading
        bool isTeacher = roleSnapshot.data ?? false;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              "My Classes",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            backgroundColor: AppColors.primary,
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),

          floatingActionButton: isTeacher
              ? Padding(
                  // ✅ This moves the button up by 80 pixels
                  padding: EdgeInsets.only(bottom: 100.h),
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateClassScreen(),
                        ),
                      );
                    },
                  ),
                )
              : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('subjects')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        "No classes found.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                // Padding to avoid hiding behind navbar
                padding: EdgeInsets.only(
                  bottom: 100.h,
                  left: 16.w,
                  right: 16.w,
                  top: 16.h,
                ),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  SubjectModel subject = SubjectModel(
                    id: docs[index].id,
                    subjectName: data['subjectName'] ?? 'Unknown',
                    subjectCode: data['subjectCode'] ?? '---',
                    teacherId: data['teacherId'] ?? '',
                    teacherName: data['teacherName'] ?? 'Teacher',
                  );

                  // Check if this specific class belongs to the current teacher
                  bool isMyClass = (user?.uid == subject.teacherId);

                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.only(bottom: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16.w),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          subject.subjectCode.isNotEmpty
                              ? subject.subjectCode.substring(0, 1)
                              : "C",
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        subject.subjectName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Code: ${subject.subjectCode} • ${subject.teacherName}",
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(
                              subject: subject,
                              isTeacher: isMyClass,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
