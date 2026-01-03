import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:gcr/studypal/Models/subject_model.dart';
import 'package:gcr/studypal/teachers/upload_material_screen.dart';
import 'package:gcr/studypal/teachers/add_schedule_dialog.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'file_viewer_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final SubjectModel subject;
  final bool isTeacher;

  const ClassDetailScreen({
    super.key,
    required this.subject,
    required this.isTeacher,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  // Search + Filter state
  final TextEditingController _materialSearchController =
      TextEditingController();
  final List<String> _types = const [
    "All",
    "Lecture",
    "Assignment",
    "Note",
    "Other",
  ];
  String _selectedType = "All";

  // --- DELETE CLASS LOGIC ---
  Future<void> _deleteClass() async {
    // 1. Show Confirmation Dialog
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "Delete Class?",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Are you sure you want to delete ${widget.subject.subjectName}? This cannot be undone.",
              style: GoogleFonts.poppins(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child: Text(
                  "Delete",
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        // 2. Perform Delete
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.subject.id)
            .delete();

        // 3. Close Screen
        if (mounted) {
          Navigator.pop(context); // Go back to list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Class deleted successfully")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error deleting class: $e")));
        }
      }
    }
  }

  Future<void> _triggerRefresh() async {
    if (!mounted) return;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    _materialSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if current user is the actual owner (extra security)
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner =
        widget.isTeacher && (currentUser?.uid == widget.subject.teacherId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Class Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        actions: [
          // --- SCHEDULE BUTTON FOR TEACHERS ---
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.schedule_outlined, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AddScheduleDialog(
                    classId: widget.subject.id,
                    subjectName: widget.subject.subjectName,
                  ),
                );
              },
              tooltip: 'Add Schedule',
            ),
          // --- SETTINGS MENU WITH DELETE OPTION ---
          if (isOwner)
            Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteClass();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8.w),
                        Text(
                          'Delete Class',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ================= HEADER SECTION =================
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Purple Background Gradient
              Container(
                height: 220.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30.r),
                    bottomRight: Radius.circular(30.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.h),
                    child: Text(
                      widget.subject.subjectName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Floating Info Card
              Positioned(
                bottom: -40.h,
                left: 24.w,
                right: 24.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 20.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn("Code", widget.subject.subjectCode),
                      Container(
                        height: 30.h,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      _buildInfoColumn(
                        "Instructor",
                        widget.subject.teacherName,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 60.h),

          // ================= SEARCH + FILTERS =================
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _materialSearchController,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search materials...",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14.sp,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2.w,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[500],
                        size: 20.sp,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        items: _types
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: GoogleFonts.poppins(fontSize: 13.sp),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedType = v ?? "All"),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // ================= MATERIALS LIST =================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .doc(widget.subject.id)
                  .collection('materials')
                  .orderBy('uploadedAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return RefreshIndicator(
                    onRefresh: _triggerRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 160.h, 20.w, 40.h),
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 56.sp,
                          color: Colors.redAccent.withValues(alpha: 0.7),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "We couldn't load class materials right now.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 14.sp),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Pull to refresh or try again later.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _triggerRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 140.h, 20.w, 40.h),
                      children: [
                        Container(
                          padding: EdgeInsets.all(22.r),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.folder_open_rounded,
                            size: 54.sp,
                            color: AppColors.primary.withValues(alpha: 0.55),
                          ),
                        ),
                        SizedBox(height: 18.h),
                        Text(
                          "No materials uploaded yet",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Once shared, new lectures and assignments will appear here automatically.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final query = _materialSearchController.text
                    .trim()
                    .toLowerCase();
                final filtered = docs.where((doc) {
                  final raw = doc.data();
                  if (raw is! Map<String, dynamic>) return false;
                  final title = (raw['title'] ?? '').toString().toLowerCase();
                  final fileName = (raw['fileName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final type = (raw['type'] ?? '').toString();

                  final matchesType =
                      _selectedType == 'All' ||
                      type.toLowerCase() == _selectedType.toLowerCase();
                  final matchesQuery =
                      query.isEmpty ||
                      title.contains(query) ||
                      fileName.contains(query);
                  return matchesType && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _triggerRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 40.h),
                      children: [
                        _buildMaterialStatsRow(docs),
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48.sp,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                "No materials match your filters",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                "Try adjusting the search text or file type to explore more resources.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _triggerRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildMaterialStatsRow(docs);
                      }

                      final doc = filtered[index - 1];
                      final raw = doc.data();
                      if (raw is! Map<String, dynamic>) {
                        return const SizedBox.shrink();
                      }

                      final title = (raw['title'] ?? 'Untitled').toString();
                      final fileName = (raw['fileName'] ?? 'Unknown File')
                          .toString();
                      final fileUrl = (raw['fileUrl'] ?? '').toString();
                      final type = (raw['type'] ?? 'Lecture').toString();
                      final DateTime? uploadedAt = _asDateTime(
                        raw['uploadedAt'],
                      );

                      final isAssignment = type.toLowerCase() == 'assignment';
                      final iconData = isAssignment
                          ? Icons.assignment_outlined
                          : Icons.description_outlined;
                      final iconColor = isAssignment
                          ? Colors.orangeAccent
                          : AppColors.primary;

                      return Container(
                        margin: EdgeInsets.only(bottom: 14.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20.r),
                            onTap: fileUrl.isEmpty
                                ? null
                                : () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FileViewerScreen(
                                          fileUrl: fileUrl,
                                          fileName: fileName,
                                        ),
                                      ),
                                    );

                                    // If user clicked "Analyze with AI", navigate back with chatbot data
                                    if (result != null &&
                                        result is Map &&
                                        result['navigateToChatbot'] == true) {
                                      if (!context.mounted) return;
                                      Navigator.pop(context, result);
                                    }
                                  },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 16.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12.r),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          iconColor.withValues(alpha: 0.14),
                                          iconColor.withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: iconColor,
                                      size: 26.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15.5.sp,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: iconColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                              child: Text(
                                                type,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: iconColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          fileName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5.sp,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 12.h),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 15.sp,
                                              color: Colors.grey[500],
                                            ),
                                            SizedBox(width: 6.w),
                                            Expanded(
                                              child: Text(
                                                _formatUploadedTime(uploadedAt),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11.5.sp,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Icon(
                                    fileUrl.isEmpty
                                        ? Icons.lock_outline_rounded
                                        : Icons.arrow_forward_ios_rounded,
                                    size: 16.sp,
                                    color: fileUrl.isEmpty
                                        ? Colors.grey[400]
                                        : AppColors.primary.withValues(
                                            alpha: 0.7,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UploadMaterialScreen(subjectId: widget.subject.id),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                "Upload",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialStatsRow(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = <String, int>{
      'Total': docs.length,
      'Lecture': 0,
      'Assignment': 0,
      'Note': 0,
      'Other': 0,
    };

    DateTime? latestUpload;

    for (final doc in docs) {
      final raw = doc.data();
      if (raw is! Map<String, dynamic>) continue;
      final type = (raw['type'] ?? '').toString().toLowerCase();
      final uploadDate = _asDateTime(raw['uploadedAt']);
      if (uploadDate != null &&
          (latestUpload == null || uploadDate.isAfter(latestUpload))) {
        latestUpload = uploadDate;
      }

      if (type == 'lecture') {
        counts.update('Lecture', (value) => value + 1);
      } else if (type == 'assignment') {
        counts.update('Assignment', (value) => value + 1);
      } else if (type == 'note') {
        counts.update('Note', (value) => value + 1);
      } else {
        counts.update('Other', (value) => value + 1);
      }
    }

    final lastUpdatedLabel = latestUpload != null
        ? 'Updated ${DateFormat('MMM d, h:mm a').format(latestUpload)}'
        : 'Awaiting first upload';

    final statCards = <Map<String, dynamic>>[
      {
        'label': 'Total Materials',
        'value': counts['Total']!,
        'subtitle': lastUpdatedLabel,
        'color': AppColors.primary,
        'icon': Icons.storage_rounded,
      },
      {
        'label': 'Lectures',
        'value': counts['Lecture']!,
        'subtitle': 'Structured sessions',
        'color': const Color(0xFF7C4DFF),
        'icon': Icons.auto_stories_rounded,
      },
      {
        'label': 'Assignments',
        'value': counts['Assignment']!,
        'subtitle': 'Track due tasks',
        'color': Colors.orangeAccent,
        'icon': Icons.assignment_turned_in_rounded,
      },
      {
        'label': 'Notes',
        'value': counts['Note']!,
        'subtitle': 'Quick references',
        'color': const Color(0xFF26A69A),
        'icon': Icons.sticky_note_2_rounded,
      },
    ];

    final displayCards = statCards
        .where(
          (card) => card['label'] == 'Total Materials'
              ? true
              : (card['value'] as int) > 0,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class insights',
          style: GoogleFonts.poppins(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 135.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: displayCards.length,
            separatorBuilder: (context, _) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final card = displayCards[index];
              return _buildStatCard(
                card['label'] as String,
                card['value'] as int,
                card['color'] as Color,
                card['icon'] as IconData,
                subtitle: card['subtitle'] as String?,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    int value,
    Color color,
    IconData icon, {
    String? subtitle,
  }) {
    return Container(
      width: 180.w,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            SizedBox(height: 3.h),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10.5.sp,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatUploadedTime(DateTime? date) {
    if (date == null) return 'Uploaded date unavailable';
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
