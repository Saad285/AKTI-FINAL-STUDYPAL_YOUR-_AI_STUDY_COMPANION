import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/messages/messages_screen.dart';
import 'package:gcr/studypal/students/hometab.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
// Required for Offset extension/constant

class StudentHomepage extends StatefulWidget {
  const StudentHomepage({super.key});

  @override
  State<StudentHomepage> createState() => _StudentHomepageState();
}

class _StudentHomepageState extends State<StudentHomepage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Hometab(),
    const MessagesScreen(),
    const Center(child: Text("AI Bot Content")),
    const Center(child: Text("Reminders Content")),
    const Center(child: Text("Classes Content")),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],

      // 👇 BOTTOM NAVIGATION BAR with Larger Icons 👇
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(45.r),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 25,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Transform.translate(
              offset: const Offset(0.0, 4.0), // Vertical alignment fix
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,

                selectedItemColor: AppColors.primary,
                unselectedItemColor: Colors.grey[400],

                // ✅ UPDATED SIZES: 28 and 32
                selectedFontSize: 0.0,
                unselectedFontSize: 0.0,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                elevation: 0,

                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined, size: 28), // Increased
                    activeIcon: Icon(Icons.home, size: 32), // Increased
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      size: 28,
                    ), // Increased
                    activeIcon: Icon(Icons.chat_bubble, size: 32),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.smart_toy_outlined, size: 28), // Increased
                    activeIcon: Icon(Icons.smart_toy, size: 32),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.notifications_outlined,
                      size: 28,
                    ), // Increased
                    activeIcon: Icon(Icons.notifications, size: 32),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.book_outlined, size: 28), // Increased
                    activeIcon: Icon(Icons.book, size: 32),
                    label: '',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
