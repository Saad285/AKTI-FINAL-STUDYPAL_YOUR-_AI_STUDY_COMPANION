import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/teacher_provider.dart';

class UploadMaterialScreen extends StatefulWidget {
  final String subjectId; // Required to know where to upload

  const UploadMaterialScreen({super.key, required this.subjectId});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final TextEditingController _titleController = TextEditingController();

  // State variables
  String _selectedType = 'Lecture Material';
  DateTime? _deadline;
  PlatformFile? _pickedFile;

  final List<String> _uploadTypes = ['Lecture Material', 'Assignment'];

  // 1. Pick File Logic (PDF, Word, Images)
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

  // 2. Pick Date Logic
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
    bool isAssignment = _selectedType == 'Assignment';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          "Upload Content",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Title Input ---
            Text("Title", style: _labelStyle()),
            SizedBox(height: 8.h),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration(
                "e.g., Week 1 Slides / Assignment 1",
              ),
            ),

            SizedBox(height: 20.h),

            // --- Material Type Dropdown ---
            Text("Type", style: _labelStyle()),
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
                    Icons.arrow_drop_down,
                    color: AppColors.primary,
                  ),
                  items: _uploadTypes.map((String type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: GoogleFonts.poppins()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      // Reset deadline if switching back to Material
                      if (_selectedType == 'Lecture Material') _deadline = null;
                    });
                  },
                ),
              ),
            ),

            // --- Deadline Picker (Conditional) ---
            if (isAssignment) ...[
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
                        Icons.calendar_today,
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
                          color: _deadline == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 20.h),

            // --- File Picker Area ---
            Text("Attachment (PDF, Word, Image)", style: _labelStyle()),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 30.h),
                decoration: BoxDecoration(
                  color: _pickedFile == null
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(
                    color: _pickedFile == null
                        ? AppColors.primary
                        : Colors.green,
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _pickedFile == null
                          ? Icons.cloud_upload_outlined
                          : _getIconForFile(_pickedFile!.extension),
                      size: 40.sp,
                      color: _pickedFile == null
                          ? AppColors.primary
                          : Colors.green,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      _pickedFile == null
                          ? "Tap to upload file"
                          : _pickedFile!.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _pickedFile == null
                            ? AppColors.primary
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 40.h),

            // --- Post Button ---
            SizedBox(
              width: double.infinity,
              height: 55.h,
              child: ElevatedButton(
                onPressed: teacherProvider.isLoading
                    ? null
                    : () {
                        // 1. Basic Validation
                        if (_titleController.text.isEmpty ||
                            _pickedFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please add a title and file"),
                            ),
                          );
                          return;
                        }

                        // 2. Assignment Validation
                        if (isAssignment && _deadline == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please set a deadline for the assignment",
                              ),
                            ),
                          );
                          return;
                        }

                        // 3. Call Upload Function
                        teacherProvider.uploadMaterial(
                          subjectId: widget.subjectId,
                          title: _titleController.text,
                          type: _selectedType,
                          file: _pickedFile!,
                          deadline: _deadline,
                          context: context,
                        );
                      },
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
                        "Post Material",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Label Style
  TextStyle _labelStyle() => GoogleFonts.poppins(
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  // Helper: Input Decoration
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14.sp),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    );
  }

  // Helper: Dynamic Icon based on extension
  IconData _getIconForFile(String? extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
