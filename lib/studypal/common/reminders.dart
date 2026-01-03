import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gcr/studypal/theme/app_colors.dart';

enum ReminderType { assignment, quiz, note }

class ReminderNote {
  ReminderNote({
    String? id,
    required this.userId,
    required this.date,
    required this.type,
    required this.title,
    this.description,
    this.classId,
    this.assigneeIds = const <String>[],
    this.createdBy,
    this.fromMaterial = false,
    this.completed = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String userId;
  final DateTime date;
  final ReminderType type;
  final String title;
  final String? description;
  final String? classId;
  final List<String> assigneeIds;
  final String? createdBy;
  final bool fromMaterial;
  final bool completed;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'title': title,
      'description': description,
      'classId': classId,
      'assigneeIds': assigneeIds,
      'createdBy': createdBy,
      'fromMaterial': fromMaterial,
      'completed': completed,
    };
  }

  factory ReminderNote.fromMap(Map<String, dynamic> map) {
    // Safety check: ensure required fields exist to prevent crashes
    try {
      return ReminderNote(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        // Handle Date safely
        date: (map['date'] is Timestamp)
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
        // Handle Enum safely
        type: ReminderType.values.firstWhere(
          (e) => e.name == (map['type'] as String?),
          orElse: () => ReminderType.note,
        ),
        title: map['title'] as String? ?? 'Untitled',
        description: map['description'] as String?,
        classId: map['classId'] as String?,
        assigneeIds:
            (map['assigneeIds'] as List?)?.whereType<String>().toList() ??
            const <String>[],
        createdBy: map['createdBy'] as String?,
        fromMaterial: map['fromMaterial'] as bool? ?? false,
        completed: map['completed'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint("Error parsing note: $e");
      // Return a placeholder or rethrow depending on strictness needed
      rethrow;
    }
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with TickerProviderStateMixin {
  // Firestore Collection
  final CollectionReference<Map<String, dynamic>> _firestoreCollection =
      FirebaseFirestore.instance.collection('reminders');

  Stream<List<String>> _userClassIdsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('students', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Stream<List<ReminderNote>> _personalNotesStream(String uid) {
    return _firestoreCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderNote.fromMap(doc.data()))
              .toList(),
        );
  }

  ReminderNote? _materialToReminder(String uid, QueryDocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final String typeString = (data['type'] as String? ?? '').toLowerCase();
      if (!(typeString.contains('assignment') || typeString.contains('quiz'))) {
        return null;
      }

      final ReminderType reminderType = typeString.contains('quiz')
          ? ReminderType.quiz
          : ReminderType.assignment;

      final Timestamp? deadlineTs = data['deadline'] is Timestamp
          ? data['deadline'] as Timestamp
          : null;
      final Timestamp? uploadedAtTs = data['uploadedAt'] is Timestamp
          ? data['uploadedAt'] as Timestamp
          : null;

      final date =
          deadlineTs?.toDate() ?? uploadedAtTs?.toDate() ?? DateTime.now();

      return ReminderNote(
        id: doc.id,
        userId: uid,
        classId: data['classId'] as String?,
        assigneeIds:
            (data['assigneeIds'] as List?)?.whereType<String>().toList() ??
            const <String>[],
        createdBy: data['createdBy'] as String?,
        fromMaterial: true,
        date: date,
        type: reminderType,
        title: data['title'] as String? ?? 'Untitled',
        description: data['description'] as String?,
      );
    } catch (e) {
      debugPrint('Skipping material reminder: $e');
      return null;
    }
  }

  Stream<List<ReminderNote>> _materialNotesStream(
    String uid,
    List<String> classIds,
  ) {
    if (classIds.isEmpty) {
      return Stream<List<ReminderNote>>.value(const []);
    }

    // To avoid the need for a collectionGroup index (which requires manual setup in Firebase Console),
    // we query each class's materials subcollection individually and merge the results.
    final cappedIds = classIds.take(10).toList();

    // We use a StreamController to merge multiple Firestore snapshots into one stream
    final controller = StreamController<List<ReminderNote>>();
    final Map<String, List<ReminderNote>> latestResults = {};
    final Set<String> initializedClasses = {};
    final List<StreamSubscription> subscriptions = [];

    void updateCombined() {
      if (controller.isClosed) return;
      final allNotes = latestResults.values.expand((list) => list).toList();
      controller.add(allNotes);
    }

    for (final classId in cappedIds) {
      final sub = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('materials')
          .snapshots()
          .listen(
            (snapshot) {
              final notes = snapshot.docs
                  .map((doc) => _materialToReminder(uid, doc))
                  .whereType<ReminderNote>()
                  .toList();

              latestResults[classId] = notes;
              initializedClasses.add(classId);

              // Emit as soon as we have data from all requested classes
              if (initializedClasses.length == cappedIds.length) {
                updateCombined();
              }
            },
            onError: (e) {
              debugPrint('Error fetching materials for class $classId: $e');
              // We don't close the whole stream on one class error, just skip it
              latestResults[classId] = [];
              initializedClasses.add(classId);
              if (initializedClasses.length == cappedIds.length) {
                updateCombined();
              }
            },
          );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    return controller.stream;
  }

  late final AnimationController _fabController;
  late final Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // Helper to group raw list into Map entries
  List<MapEntry<DateTime, List<ReminderNote>>> _groupReminders(
    List<ReminderNote> reminders,
  ) {
    final grouped = <DateTime, List<ReminderNote>>{};
    for (final note in reminders) {
      final key = DateTime(note.date.year, note.date.month, note.date.day);
      grouped.putIfAbsent(key, () => []).add(note);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return [for (final key in sortedKeys) MapEntry(key, grouped[key]!)];
  }

  Future<void> _addReminder(ReminderNote note) async {
    try {
      await _firestoreCollection.doc(note.id).set(note.toMap());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving reminder: $e')));
      }
    }
  }

  Future<void> _deleteReminder(ReminderNote note) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Material reminders are derived from class uploads; don't delete those here.
    if (note.fromMaterial) return;
    if (note.userId != user.uid) return;

    try {
      await _firestoreCollection.doc(note.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting reminder: $e')));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _typeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.assignment:
        return 'Assignment';
      case ReminderType.quiz:
        return 'Quiz';
      case ReminderType.note:
        return 'Note';
    }
  }

  Color _typeColor(ReminderType type) {
    switch (type) {
      case ReminderType.assignment:
        return AppColors.primary;
      case ReminderType.quiz:
        return AppColors.secondary;
      case ReminderType.note:
        return AppColors.primary.withValues(alpha: 0.75);
    }
  }

  void _openAddReminderSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add reminders.')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    ReminderType selectedType = ReminderType.assignment;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 1095)),
              );
              if (picked != null) {
                setModalState(() => selectedDate = picked);
              }
            }

            final canSave = titleCtrl.text.trim().isNotEmpty;

            void save() {
              final title = titleCtrl.text.trim();
              final description = descCtrl.text.trim();
              if (title.isEmpty) return;

              _addReminder(
                ReminderNote(
                  userId: user.uid,
                  createdBy: user.uid,
                  date: selectedDate,
                  type: selectedType,
                  title: title,
                  description: description.isEmpty ? null : description,
                ),
              );
              Navigator.of(sheetContext).pop();
            }

            return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(top: 80),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_task_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Add New Reminder',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 24,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleCtrl,
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Reminder Title',
                                  hintText: 'Enter reminder title',
                                  prefixIcon: Icon(
                                    Icons.title_rounded,
                                    color: AppColors.primary,
                                  ),
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppColors.onSurface.withValues(alpha: 0.4),
                                  ),
                                  labelStyle: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.primary.withValues(alpha: 
                                    0.05,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: descCtrl,
                                minLines: 3,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  labelText: 'Description (Optional)',
                                  hintText:
                                      'Add additional details or notes...',
                                  alignLabelWithHint: true,
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppColors.onSurface.withValues(alpha: 0.4),
                                  ),
                                  labelStyle: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.primary.withValues(alpha: 
                                    0.05,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<ReminderType>(
                                initialValue: selectedType,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(
                                    Icons.category_rounded,
                                    color: AppColors.primary,
                                  ),
                                  labelStyle: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.primary.withValues(alpha: 
                                    0.05,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: ReminderType.values
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(_typeLabel(type)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setModalState(() => selectedType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: pickDate,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      'Due Date',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _formatDate(selectedDate),
                                      style: GoogleFonts.poppins(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: canSave
                                        ? [
                                            AppColors.primary,
                                            AppColors.primary.withValues(alpha: 0.8),
                                          ]
                                        : [
                                            Colors.grey.shade300,
                                            Colors.grey.shade300,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: canSave
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ElevatedButton(
                                  onPressed: canSave ? save : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save Reminder',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate(key: const ValueKey('add_reminder_sheet_anim'))
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .move(begin: const Offset(0, 100));
          },
        );
      },
    ).whenComplete(() {
      titleCtrl.dispose();
      descCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Safety check for Login
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view reminders")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.white,
              ),
            ),
          ),
          title: Text(
            'My Reminders',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.universalGradient,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: _userClassIdsStream(user.uid),
                      builder: (context, classSnapshot) {
                        final classIds = classSnapshot.data ?? const <String>[];

                        return StreamBuilder<List<ReminderNote>>(
                          stream: _personalNotesStream(user.uid),
                          builder: (context, personalSnapshot) {
                            if (personalSnapshot.hasError) {
                              return Center(
                                child: Text("Error: ${personalSnapshot.error}"),
                              );
                            }

                            if (personalSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            final personalNotes =
                                personalSnapshot.data ?? const <ReminderNote>[];

                            return StreamBuilder<List<ReminderNote>>(
                              stream: _materialNotesStream(user.uid, classIds),
                              builder: (context, materialSnapshot) {
                                if (materialSnapshot.hasError) {
                                  return Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 
                                          0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: AppColors.error,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Could not load class materials",
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "Your personal reminders will still be displayed",
                                            style: TextStyle(
                                              color: AppColors.error
                                                  .withValues(alpha: 0.8),
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final materialNotes =
                                    materialSnapshot.data ??
                                    const <ReminderNote>[];

                                final allNotes = [
                                  ...personalNotes,
                                  ...materialNotes,
                                ]..sort((a, b) => a.date.compareTo(b.date));

                                final groupedEntries = _groupReminders(
                                  allNotes,
                                );

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: groupedEntries.isEmpty
                                      ? _buildEmptyState(context)
                                      : _buildRemindersList(
                                          user.uid,
                                          groupedEntries,
                                        ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 24,
            child: ScaleTransition(
              scale: _fabAnimation,
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _openAddReminderSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add Reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('empty'),
      child:
          Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 200),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 0,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.1),
                                      AppColors.primary.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.2),
                                      AppColors.primary.withValues(alpha: 0.15),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No Reminders Yet',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Stay organized and never miss a deadline',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create reminders for assignments, quizzes, and important events',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurface.withValues(alpha: 0.55),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.assignment_outlined,
                            title: 'Tasks',
                            color: const Color(0xFF5C6BC0),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.quiz_outlined,
                            title: 'Quizzes',
                            color: const Color(0xFFFF7043),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.event_note_outlined,
                            title: 'Notes',
                            color: const Color(0xFF26A69A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 700.ms, curve: Curves.easeOutCubic)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 700.ms,
                curve: Curves.easeOutBack,
              ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList(
    String currentUserId,
    List<MapEntry<DateTime, List<ReminderNote>>> groupedEntries,
  ) {
    return ListView.builder(
      // STABILIZED: Removed complex Key logic here to prevent conflicts.
      // ListView handles its own diffing fine.
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final entry = groupedEntries[index];
        final notes = entry.value;

        return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDate(entry.key),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...notes.asMap().entries.map((noteEntry) {
                    final note = noteEntry.value;
                    final canDelete =
                        !note.fromMaterial && (note.userId == currentUserId);
                    return Padding(
                      key: Key(note.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          _ReminderCard(
                                note: note,
                                typeLabel: _typeLabel(note.type),
                                accent: _typeColor(note.type),
                                onDelete: canDelete
                                    ? () {
                                        _deleteReminder(note);
                                      }
                                    : null,
                              )
                              .animate(
                                delay: ((index * 80) + (noteEntry.key * 60)).ms,
                              )
                              .fadeIn(
                                duration: 600.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .move(
                                begin: const Offset(30, 10),
                                duration: 600.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                end: const Offset(1.0, 1.0),
                                duration: 600.ms,
                                curve: Curves.easeOutCubic,
                              ),
                    );
                  }),
                ],
              ),
            )
            .animate(delay: (index * 80).ms)
            .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
            .move(
              begin: const Offset(40, 0),
              duration: 500.ms,
              curve: Curves.easeOutCubic,
            )
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
              duration: 500.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

class _ReminderCard extends StatefulWidget {
  const _ReminderCard({
    required this.note,
    required this.typeLabel,
    required this.accent,
    this.onDelete,
  });

  final ReminderNote note;
  final String typeLabel;
  final Color accent;
  final VoidCallback? onDelete;

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _isHovered = false;

  IconData _getTypeIcon(ReminderType type) {
    switch (type) {
      case ReminderType.assignment:
        return Icons.assignment_outlined;
      case ReminderType.quiz:
        return Icons.quiz_outlined;
      case ReminderType.note:
        return Icons.note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      widget.note.date.year,
      widget.note.date.month,
      widget.note.date.day,
    );
    final dayDelta = dueDate.difference(today).inDays;
    final overdue = dayDelta < 0;
    final dueToday = dayDelta == 0;
    final dueDescription = overdue
        ? 'Overdue by ${dayDelta.abs()} day${dayDelta.abs() == 1 ? '' : 's'}'
        : dueToday
        ? 'Due today'
        : 'Due in $dayDelta day${dayDelta == 1 ? '' : 's'}';

    final scale = _isHovered ? 1.03 : 1.0;
    final translationY = _isHovered ? -6.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      transform: Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(0.0, translationY, 0.0),
      child: InkWell(
        splashColor: widget.accent.withValues(alpha: 0.1),
        highlightColor: widget.accent.withValues(alpha: 0.05),
        onTap: () {},
        onHover: (hovering) {
          setState(() => _isHovered = hovering);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent.withValues(alpha: 0.10),
                widget.accent.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accent.withValues(alpha: _isHovered ? 0.3 : 0.1),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.accent,
                            widget.accent.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getTypeIcon(widget.note.type),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.onSurface.withValues(alpha: 0.9),
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                overdue
                                    ? Icons.warning_rounded
                                    : Icons.schedule_rounded,
                                size: 14,
                                color: overdue
                                    ? AppColors.error
                                    : (dueToday
                                          ? AppColors.primary
                                          : AppColors.onSurface.withValues(alpha: 
                                              0.6,
                                            )),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dueDescription,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: overdue
                                          ? AppColors.error
                                          : (dueToday
                                                ? AppColors.primary
                                                : AppColors.onSurface
                                                      .withValues(alpha: 0.6)),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                          // Add subject name if classId exists
                          if (widget.note.classId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('classes')
                                    .doc(widget.note.classId)
                                    .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data != null &&
                                      snapshot.data!.exists) {
                                    final classData =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>?;
                                    final subjectName =
                                        classData?['subjectName'] as String? ??
                                        'Unknown Subject';
                                    return Row(
                                      children: [
                                        Icon(
                                          Icons.book_rounded,
                                          size: 13,
                                          color: widget.accent.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            subjectName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: widget.accent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onDelete != null)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: widget.onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                if (widget.note.description != null &&
                    widget.note.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.note.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.typeLabel,
                        style: GoogleFonts.poppins(
                          color: widget.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
