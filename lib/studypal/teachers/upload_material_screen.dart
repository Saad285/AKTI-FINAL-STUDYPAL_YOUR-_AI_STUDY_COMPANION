import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/teacher_provider.dart';

class UploadMaterialScreen extends StatefulWidget {
  final String subjectId;

  const UploadMaterialScreen({super.key, required this.subjectId});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedType = 'Lecture Material';
  DateTime? _deadline;
  PlatformFile? _pickedFile;

  final List<String> _uploadTypes = ['Lecture Material', 'Assignment', 'Quiz'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
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
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherProvider = Provider.of<TeacherProvider>(context);
    final bool needsDeadline =
        _selectedType == 'Assignment' || _selectedType == 'Quiz';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // --- UPDATED: Primary Color Background ---
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          // --- UPDATED: White Icon ---
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Upload Content",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
            // --- UPDATED: White Text ---
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h), // Added a bit more top spacing
            // ---------- TITLE ----------
            Text("Title", style: _labelStyle()),
            SizedBox(height: 8.h),
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(fontSize: 14.sp),
              decoration: _inputDecoration("e.g., Week 1 Slides"),
            ),

            SizedBox(height: 20.h),

            // ---------- DESCRIPTION ----------
            Text("Description", style: _labelStyle()),
            SizedBox(height: 8.h),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 14.sp),
              keyboardType: TextInputType.multiline,
              decoration: _inputDecoration("Add instructions or notes..."),
            ),

            SizedBox(height: 20.h),

            // ---------- TYPE SELECTION ----------
            Text("Content Type", style: _labelStyle()),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                  items: _uploadTypes.map((String type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      if (_selectedType == 'Lecture Material') {
                        _deadline = null;
                      }
                    });
                  },
                ),
              ),
            ),

            // ---------- DEADLINE (Animation) ----------
            AnimatedCrossFade(
              firstChild: Container(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),
                  Text("Deadline", style: _labelStyle()),
                  SizedBox(height: 8.h),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 16.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: _deadline == null
                              ? Colors.grey.shade200
                              : AppColors.primary,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 20.sp,
                            color: _deadline == null
                                ? Colors.grey
                                : AppColors.primary,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            _deadline == null
                                ? "Select Submission Date"
                                : DateFormat('MMM dd, yyyy').format(_deadline!),
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: _deadline == null
                                  ? Colors.grey
                                  : Colors.black87,
                              fontWeight: _deadline == null
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              crossFadeState: needsDeadline
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),

            SizedBox(height: 24.h),

            // ---------- FILE PICKER (Enhanced) ----------
            Text("Attachment", style: _labelStyle()),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 30.h),
                decoration: BoxDecoration(
                  color: _pickedFile == null
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: _pickedFile == null
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.green,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _pickedFile == null
                            ? Icons.cloud_upload_rounded
                            : _getIconForFile(_pickedFile!.extension),
                        size: 32.sp,
                        color: _pickedFile == null
                            ? AppColors.primary
                            : Colors.green,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      _pickedFile == null
                          ? "Tap to browse files"
                          : _pickedFile!.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _pickedFile == null
                            ? AppColors.primary
                            : Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    if (_pickedFile == null)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          "PDF, Word, or Images",
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 40.h),

            // ---------- POST BUTTON ----------
            SizedBox(
              width: double.infinity,
              height: 55.h,
              child: ElevatedButton(
                onPressed: teacherProvider.isLoading
                    ? null
                    : () {
                        if (_titleController.text.isEmpty ||
                            _pickedFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please add a title and file"),
                            ),
                          );
                          return;
                        }
                        if (needsDeadline && _deadline == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please set a deadline"),
                            ),
                          );
                          return;
                        }

                        teacherProvider.uploadMaterial(
                          subjectId: widget.subjectId,
                          title: _titleController.text,
                          description: _descriptionController.text,
                          type: _selectedType,
                          file: _pickedFile!,
                          deadline: _deadline,
                          context: context,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 5,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: teacherProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Upload Material",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  // ---------- HELPERS ----------
  TextStyle _labelStyle() => GoogleFonts.poppins(
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13.sp),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    );
  }

  IconData _getIconForFile(String? extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
