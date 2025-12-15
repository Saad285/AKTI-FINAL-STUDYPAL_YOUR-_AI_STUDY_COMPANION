import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // <--- ADDED: Needed for Provider
import 'package:gcr/studypal/Models/subject_model.dart';
import 'package:gcr/studypal/providers/teacher_provider.dart'; // <--- ADDED: Import TeacherProvider
import 'package:gcr/studypal/teachers/upload_material_screen.dart';
import 'package:gcr/studypal/theme/animated_background.dart';
import 'package:gcr/studypal/theme/app_theme.dart';
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
  String? _expandedDocId;
  final Map<String, String> _selectedFiles = {};

  // --- FUNCTION: EDIT DEADLINE (Teachers Only) ---
  Future<void> _editDeadline(
    BuildContext context,
    String materialId,
    DateTime? currentDeadline,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDeadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // Call the editMaterial function from TeacherProvider
      await Provider.of<TeacherProvider>(context, listen: false).editMaterial(
        subjectId: widget.subject.id,
        materialId: materialId,
        deadline: picked,
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      colors: AppTheme.primaryGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: Text(
            widget.subject.subjectName,
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
            if (widget.isTeacher)
              IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            // --- HEADER ---
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
                    "Subject Code: ${widget.subject.subjectCode}",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Instructor: ${widget.subject.teacherName}",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // --- MATERIALS LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classes')
                    .doc(widget.subject.id)
                    .collection('materials')
                    .orderBy('uploadedAt', descending: true)
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
                            Icons.folder_open_rounded,
                            size: 60.sp,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 15.h),
                          Text(
                            "No materials uploaded yet",
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String docId = doc.id;

                      String fileName = data['fileName'] ?? 'Unknown File';
                      String fileUrl = data['fileUrl'] ?? '';
                      String title = data['title'] ?? 'Untitled';
                      String description = data['description'] ?? '';
                      String type = data['type'] ?? 'lecture';

                      Timestamp? deadlineTs = data['deadline'];
                      DateTime? deadline = deadlineTs?.toDate();
                      String formattedDeadline = deadline != null
                          ? DateFormat('MMM dd, yyyy').format(deadline)
                          : "No Deadline";

                      bool isExpanded = _expandedDocId == docId;
                      String? pickedFile = _selectedFiles[docId];

                      IconData fileIcon;
                      if (type == 'assignment') {
                        fileIcon = Icons.assignment_outlined;
                      } else {
                        String lowerName = fileName.toLowerCase();
                        if (lowerName.contains('.pdf')) {
                          fileIcon = Icons.picture_as_pdf;
                        } else if (lowerName.contains('.doc')) {
                          fileIcon = Icons.description;
                        } else if (lowerName.contains('.jpg') ||
                            lowerName.contains('.png')) {
                          fileIcon = Icons.image;
                        } else {
                          fileIcon = Icons.insert_drive_file;
                        }
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.all(12.w),
                              leading: Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(fileIcon, color: AppColors.primary),
                              ),
                              title: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  // --- DEADLINE DISPLAY & EDIT ---
                                  if (type == 'assignment')
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.h),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14.sp,
                                            color: Colors.redAccent,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            deadline != null
                                                ? "Due: $formattedDeadline"
                                                : "No Deadline Set",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.sp,
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          // --- EDIT BUTTON (Teachers Only) ---
                                          if (widget.isTeacher) ...[
                                            SizedBox(width: 8.w),
                                            InkWell(
                                              onTap: () => _editDeadline(
                                                context,
                                                docId,
                                                deadline,
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.all(4.w),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.edit_calendar,
                                                  size: 16.sp,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: type == 'assignment'
                                  ? Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                              onTap: () {
                                if (type == 'assignment') {
                                  setState(() {
                                    _expandedDocId = _expandedDocId == docId
                                        ? null
                                        : docId;
                                  });
                                } else {
                                  if (fileUrl.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FileViewerScreen(
                                          fileUrl: fileUrl,
                                          fileName: fileName,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),

                            // --- EXPANDED SECTION ---
                            if (isExpanded)
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (description.isNotEmpty) ...[
                                      Text(
                                        "Instructions:",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        description,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 15.h),
                                    ],
                                    Text(
                                      "Submit Assignment:",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedFiles[docId] =
                                              "Solved_$fileName";
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        height: 60.h,
                                        decoration: BoxDecoration(
                                          color: pickedFile == null
                                              ? const Color(0xFFF8F8FF)
                                              : const Color(0xFFF0FFF0),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                          border: Border.all(
                                            color: pickedFile == null
                                                ? AppColors.primary.withOpacity(
                                                    0.5,
                                                  )
                                                : Colors.green,
                                          ),
                                        ),
                                        child: Center(
                                          child: pickedFile == null
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .cloud_upload_outlined,
                                                      color: AppColors.primary,
                                                      size: 20.sp,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      "Tap to attach file",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: AppColors
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12.sp,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Flexible(
                                                      child: Text(
                                                        pickedFile,
                                                        style:
                                                            GoogleFonts.poppins(
                                                              color:
                                                                  Colors.green,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12.sp,
                                                            ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                    if (pickedFile != null)
                                      Padding(
                                        padding: EdgeInsets.only(top: 15.h),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 45.h,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _expandedDocId = null;
                                                _selectedFiles.remove(docId);
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "Assignment Submitted Successfully!",
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10.r),
                                              ),
                                            ),
                                            child: Text(
                                              "Submit Work",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
      ),
    );
  }
}
