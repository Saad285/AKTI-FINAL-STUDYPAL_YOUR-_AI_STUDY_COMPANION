import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gcr/studypal/providers/teacher_provider.dart';
import 'package:gcr/studypal/theme/app_colors.dart';

class AddScheduleDialog extends StatefulWidget {
  final String classId;
  final String subjectName;

  const AddScheduleDialog({
    super.key,
    required this.classId,
    required this.subjectName,
  });

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedDay = 'Monday';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _classType = 'On Campus'; // or 'Online'
  final TextEditingController _locationController =
      TextEditingController(); // Room or Link

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedTime = _selectedTime.format(context);
    final teacherId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await Provider.of<TeacherProvider>(
        context,
        listen: false,
      ).addClassSchedule(
        classId: widget.classId,
        teacherId: teacherId,
        day: _selectedDay,
        time: formattedTime,
        subjectName: widget.subjectName,
        type: _classType,
        location: _locationController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule Added Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add Schedule for ${widget.subjectName}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: const InputDecoration(labelText: 'Select Day'),
                items: _days
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedDay = val!),
              ),
              const SizedBox(height: 10),

              // Time Picker
              ListTile(
                title: Text("Time: ${_selectedTime.format(context)}"),
                trailing: const Icon(Icons.access_time),
                onTap: _pickTime,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),

              // Type (Online/On Campus)
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'On Campus',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: 'On Campus',
                      groupValue: _classType,
                      onChanged: (val) => setState(() => _classType = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Online',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: 'Online',
                      groupValue: _classType,
                      onChanged: (val) => setState(() => _classType = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              // Room No or Link Input
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: _classType == 'On Campus'
                      ? 'Room Number'
                      : 'Class Link',
                  hintText: _classType == 'On Campus'
                      ? 'e.g., Room 101'
                      : 'e.g., https://zoom.us/...',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSchedule,
          child: const Text('Add Schedule'),
        ),
      ],
    );
  }
}
