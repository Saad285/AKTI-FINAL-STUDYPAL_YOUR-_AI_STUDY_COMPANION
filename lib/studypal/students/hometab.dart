import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/messages/unread_chats_card.dart';
import 'package:gcr/studypal/teachers/class_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gcr/studypal/theme/animated_background.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:gcr/studypal/students/buildinfocard.dart';
import 'package:gcr/studypal/students/schedulecard.dart';
import 'package:gcr/studypal/Authentication/loginpage.dart';

class Hometab extends StatelessWidget {
  const Hometab({super.key});

  Future<DocumentSnapshot?> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color infoTextColor = Colors.white;

    final List<Color> backgroundColors = [
      const Color(0xFFE0F7FA),
      AppColors.primary.withOpacity(0.2),
      const Color.fromARGB(255, 234, 234, 234),
    ];

    return FutureBuilder<DocumentSnapshot?>(
      future: _fetchUserData(),
      builder: (context, snapshot) {
        String userName = "Loading...";
        bool isTeacher = false;

        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;
          userName = "Hello ${data['name'] ?? 'User'}";
          isTeacher = data['role'] == 'teacher';
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {},
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
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: GestureDetector(
                  onTap: () => _logout(context),
                  child: CircleAvatar(
                    radius: 16.r,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: AnimatedBackground(
            colors: backgroundColors,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. THE HEADER
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
                    child: Text(
                      userName,
                      style: GoogleFonts.poppins(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 30.h),

                  // 2. THE CONTENT
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTeacher ? "My Dashboard" : "What's new",
                          style: GoogleFonts.poppins(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 18.h),

                        // DYNAMIC CARDS ROW
                        Row(
                          children: [
                            IinfoCard(
                              title: isTeacher ? "Active" : "Upcoming",
                              number: isTeacher ? "3" : "7",
                              subtitle: isTeacher ? "classes" : "exams",
                              bgColor: const Color(0xFF757BC8),
                              textColor: infoTextColor,
                              width: 120,
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: IinfoCard(
                                title: "Pending",
                                number: "16",
                                subtitle: isTeacher ? "grading" : "homeworks",
                                bgColor: const Color(0xFFFFB13D),
                                textColor: infoTextColor,
                                width: double.infinity,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),

                        // ACTION ROW (Create Class / Join Class)
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (isTeacher) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CreateClassScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: IinfoCard(
                                  title: isTeacher ? "Create" : "New",
                                  number: isTeacher ? "+" : "3",
                                  subtitle: isTeacher ? "new class" : "classes",
                                  bgColor: isTeacher
                                      ? Colors.green
                                      : const Color(0xFFFFB13D),
                                  textColor: infoTextColor,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            SizedBox(width: 14.w),
                            const UnreadChatsCard(),
                          ],
                        ),

                        SizedBox(height: 30.h),

                        // SCHEDULE HEADER
                        Text(
                          "Today's schedule",
                          style: GoogleFonts.poppins(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 14.h),

                        // Hardcoded schedule cards
                        ScheduleCard(
                          subject: "Mathematics",
                          details: "Room 101",
                          startTime: "9:00 AM",
                          isOnline: false,
                        ),
                        SizedBox(height: 12.h),
                        ScheduleCard(
                          subject: "Physics",
                          details: "https://zoom.us/j/123",
                          startTime: "11:00 AM",
                          isOnline: true,
                        ),
                        SizedBox(height: 12.h),
                        ScheduleCard(
                          subject: "Chemistry",
                          details: "Lab 02",
                          startTime: "2:00 PM",
                          isOnline: false,
                        ),

                        SizedBox(height: 120.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
