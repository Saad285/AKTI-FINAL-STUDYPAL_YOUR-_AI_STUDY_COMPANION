import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/messages/unread_chats_card.dart';
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

  Future<String> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Guest";

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return userDoc.exists ? "Hello " + userDoc['name'] : "User";
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          tooltip: 'Open navigation menu',
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
              // 1. THE HEADER (Full Width, No Padding around it)
              // This container touches the edges and the AppBar
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 30.h),
                decoration: const BoxDecoration(
                  color: AppColors.primary, // Matches AppBar
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: FutureBuilder<String>(
                  future: _fetchUserName(),
                  builder: (context, snapshot) {
                    String greetingText = snapshot.data ?? "Hello StudyPal!";
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      greetingText = "Welcome...";
                    }

                    return Text(
                      greetingText,
                      style: GoogleFonts.poppins(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 30.h),

              // 2. THE CONTENT (Wrapped in Padding)
              // We apply padding here so the cards don't touch the screen edges
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's new",
                      style: GoogleFonts.poppins(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 18.h),

                    Row(
                      children: [
                        IinfoCard(
                          title: "Upcoming",
                          number: "7",
                          subtitle: "exams",
                          bgColor: const Color(0xFF757BC8),
                          textColor: infoTextColor,
                          width: 120,
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: IinfoCard(
                            title: "Pending",
                            number: "16",
                            subtitle: "homeworks",
                            bgColor: const Color(0xFFFFB13D),
                            textColor: infoTextColor,
                            width: double.infinity,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Expanded(
                          child: IinfoCard(
                            title: "New",
                            number: "3",
                            subtitle: "classes",
                            bgColor: const Color(0xFFFFB13D),
                            textColor: infoTextColor,
                            width: double.infinity,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        const UnreadChatsCard(),
                      ],
                    ),

                    SizedBox(height: 30.h),
                    Text(
                      "Today's schedule",
                      style: GoogleFonts.poppins(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    ScheduleCard(
                      subject: "Maths 101",
                      details: "classes",
                      startTime: "10:00 AM",
                      isOnline: false,
                      onTap: null,
                    ),
                    SizedBox(height: 10.h),
                    ScheduleCard(
                      subject: "Physics Lab",
                      details: "Online",
                      startTime: "12:00 PM",
                      isOnline: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Joining Physics Lab Session...'),
                          ),
                        );
                      },
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
  }
}
