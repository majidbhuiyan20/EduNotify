import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<ClassEvent>> _events = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _currentUserId = _auth.currentUser?.uid;
    _loadUserClasses();
  }

  Future<void> _loadUserClasses() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print('Loading classes for user: $_currentUserId');

      // Try without orderBy first to see if that's the issue
      final snapshot = await _firestore
          .collection('classes')
          .where('uid', isEqualTo: _currentUserId)
          .get();

      print('Found ${snapshot.docs.length} classes');

      setState(() {
        _events.clear();
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            print('Processing document ${doc.id}: $data');

            final classEvent = ClassEvent.fromMap(data);
            final timestamp = data['date'];
            if (timestamp is Timestamp) {
              final date = timestamp.toDate();
              final key = DateTime(date.year, date.month, date.day);

              if (_events.containsKey(key)) {
                _events[key]!.add(classEvent);
              } else {
                _events[key] = [classEvent];
              }
              print('Added class: ${classEvent.title} on $key');
            } else {
              print('Invalid date format: $timestamp');
            }
          } catch (e) {
            print('Error processing document ${doc.id}: $e');
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load classes: ${e.toString()}');
    }
  }

  Future<void> _addClassToFirestore(ClassEvent event, DateTime date) async {
    if (_currentUserId == null) {
      _showErrorSnackBar('Please sign in to add classes');
      return;
    }

    try {
      final classData = {
        ...event.toMap(date),
        'uid': _currentUserId,
      };

      print('Adding class to Firestore: $classData');

      final docRef = await _firestore
          .collection('classes')
          .add(classData);

      print('Class added with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding class: $e');
      throw e;
    }
  }

  Future<void> _updateClassInFirestore(ClassEvent event, DateTime date) async {
    if (_currentUserId == null) return;

    try {
      // Find the document ID for this class
      final snapshot = await _firestore
          .collection('classes')
          .where('uid', isEqualTo: _currentUserId)
          .where('id', isEqualTo: event.id)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final updateData = {
          ...event.toMap(date),
          'uid': _currentUserId,
        };
        await snapshot.docs.first.reference.update(updateData);
        print('Class updated: ${event.id}');
      } else {
        print('No class found with id: ${event.id}');
        throw Exception('Class not found');
      }
    } catch (e) {
      print('Error updating class: $e');
      throw e;
    }
  }

  Future<void> _deleteClassFromFirestore(String classId) async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('uid', isEqualTo: _currentUserId)
          .where('id', isEqualTo: classId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
        print('Class deleted: $classId');
      } else {
        print('No class found with id: $classId');
      }
    } catch (e) {
      print('Error deleting class: $e');
      throw e;
    }
  }

  Future<void> _deleteAllClassInstances(String baseClassId) async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('uid', isEqualTo: _currentUserId)
          .where('baseClassId', isEqualTo: baseClassId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Deleted ${snapshot.docs.length} instances of class: $baseClassId');
    } catch (e) {
      print('Error deleting class series: $e');
      throw e;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<ClassEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Future<void> _addClass(ClassEvent newClass, DateTime startDate, List<int> recurringDays, int weeks) async {
    try {
      for (int week = 0; week < weeks; week++) {
        for (int day in recurringDays) {
          DateTime classDate = startDate.add(Duration(days: (week * 7) + (day - startDate.weekday) % 7));

          // Create a unique ID for each instance but keep track of the series
          final instanceClass = newClass.copyWith(
            id: '${newClass.id}_${classDate.millisecondsSinceEpoch}',
            baseClassId: newClass.id,
            isRecurring: true,
          );

          // Add to Firestore first
          await _addClassToFirestore(instanceClass, classDate);
        }
      }

      // Reload data from Firestore to ensure consistency
      await _loadUserClasses();
      _showSuccessSnackBar('Class series added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add class: $e');
    }
  }

  Future<void> _addSingleClass(ClassEvent newClass, DateTime date) async {
    try {
      // Create a unique ID for the single class
      final singleClass = newClass.copyWith(
        id: 'single_${date.millisecondsSinceEpoch}',
        baseClassId: 'single_${date.millisecondsSinceEpoch}',
        isRecurring: false,
      );

      // Add to Firestore
      await _addClassToFirestore(singleClass, date);

      // Reload data
      await _loadUserClasses();
      _showSuccessSnackBar('Class added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add class: $e');
    }
  }

  Future<void> _editSingleClass(ClassEvent updatedClass, DateTime originalDate, DateTime newDate) async {
    try {
      // Remove from original date in Firestore
      await _deleteClassFromFirestore(updatedClass.id);

      // Add to new date with updated date
      final updatedInstance = updatedClass.copyWith(
        id: updatedClass.isRecurring
            ? '${updatedClass.baseClassId}_${newDate.millisecondsSinceEpoch}'
            : 'single_${newDate.millisecondsSinceEpoch}',
      );

      // Add to Firestore
      await _addClassToFirestore(updatedInstance, newDate);

      // Reload data
      await _loadUserClasses();
      _showSuccessSnackBar('Class updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update class: $e');
    }
  }

  Future<void> _editClassSeries(ClassEvent updatedClass, DateTime originalDate, DateTime newDate, List<int> recurringDays, int weeks) async {
    try {
      // First remove all instances from Firestore
      await _deleteAllClassInstances(updatedClass.baseClassId);

      // Then add the updated class with new schedule
      final updatedBaseClass = updatedClass.copyWith(
        id: updatedClass.baseClassId, // Use the original base ID
        isRecurring: true,
      );

      await _addClass(updatedBaseClass, newDate, recurringDays, weeks);
      _showSuccessSnackBar('Class series updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update class series: $e');
    }
  }

  Future<void> _deleteClass(String classId, DateTime date) async {
    try {
      // Remove from Firestore
      await _deleteClassFromFirestore(classId);

      // Reload data
      await _loadUserClasses();
      _showSuccessSnackBar('Class deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to delete class: $e');
    }
  }

  void _deleteAllInstances(String baseClassId) {
    setState(() {
      _events.forEach((key, events) {
        events.removeWhere((event) => event.baseClassId == baseClassId);
      });
      _events.removeWhere((key, events) => events.isEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _getEventsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Class Schedule', style: GoogleFonts.poppins()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Calendar'),
              Tab(text: 'List View'),
            ],
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading classes...', style: GoogleFonts.poppins()),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          // Calendar View
          Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 30)),
                lastDay: DateTime.now().add(const Duration(days: 180)),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  markersAutoAligned: true,
                  markerSize: 6,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  formatButtonTextStyle: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDay!),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${events.length} classes',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: events.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No classes scheduled',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first class',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildClassItem(events[index], _selectedDay!);
                  },
                ),
              ),
            ],
          ),

          // List View
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Upcoming Classes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () {
                        setState(() {
                          _tabController.animateTo(0);
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _events.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No classes scheduled yet',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first class using the + button',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  children: _getUpcomingWeekEvents(),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddClassDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _getUpcomingWeekEvents() {
    List<Widget> widgets = [];
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime day = now.add(Duration(days: i));
      List<ClassEvent> dayEvents = _getEventsForDay(day);

      if (dayEvents.isNotEmpty) {
        widgets.add(_buildDaySchedule(day, dayEvents));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No classes scheduled for the next 7 days',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildDaySchedule(DateTime day, List<ClassEvent> events) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMMM d').format(day),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: events.map((event) => _buildClassItem(event, day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassItem(ClassEvent event, DateTime date) {
    Color bgColor;
    IconData icon;

    switch (event.type) {
      case ClassType.lecture:
        bgColor = Colors.blue.withOpacity(0.1);
        icon = Icons.school;
        break;
      case ClassType.lab:
        bgColor = Colors.green.withOpacity(0.1);
        icon = Icons.computer;
        break;
      case ClassType.tutorial:
        bgColor = Colors.orange.withOpacity(0.1);
        icon = Icons.group;
        break;
      case ClassType.discussion:
        bgColor = Colors.purple.withOpacity(0.1);
        icon = Icons.forum;
        break;
      case ClassType.seminar:
        bgColor = Colors.teal.withOpacity(0.1);
        icon = Icons.record_voice_over;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: Icon(icon, color: _getColorForType(event.type)),
        ),
        title: Text(
          event.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              event.time,
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
            ),
            Text(
              '${event.location} • ${event.instructor}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (event.isRecurring) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.repeat, size: 12, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Recurring',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          onSelected: (value) {
            if (value == 'edit_single') {
              _showEditSingleClassDialog(event: event, date: date);
            } else if (value == 'edit_series' && event.isRecurring) {
              _showEditSeriesDialog(event: event, date: date);
            } else if (value == 'delete') {
              _showDeleteConfirmation(event, date);
            } else if (value == 'delete_all' && event.isRecurring) {
              _showDeleteAllConfirmation(event);
            }
          },
          itemBuilder: (BuildContext context) {
            List<PopupMenuItem<String>> items = [
              PopupMenuItem<String>(
                value: 'edit_single',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit This Class'),
                  ],
                ),
              ),
              if (event.isRecurring)
                PopupMenuItem<String>(
                  value: 'edit_series',
                  child: Row(
                    children: [
                      Icon(Icons.edit_calendar, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Edit Entire Series'),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete This Class'),
                  ],
                ),
              ),
              if (event.isRecurring)
                PopupMenuItem<String>(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete All Series'),
                    ],
                  ),
                ),
            ];
            return items;
          },
        ),
        onTap: () {
          _showClassDetails(event, date);
        },
      ),
    );
  }

  Color _getColorForType(ClassType type) {
    switch (type) {
      case ClassType.lecture:
        return Colors.blue;
      case ClassType.lab:
        return Colors.green;
      case ClassType.tutorial:
        return Colors.orange;
      case ClassType.discussion:
        return Colors.purple;
      case ClassType.seminar:
        return Colors.teal;
    }
  }

  void _showClassDetails(ClassEvent event, DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          event.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.access_time, event.time),
            _buildDetailRow(Icons.location_on, event.location),
            _buildDetailRow(Icons.person, event.instructor),
            _buildDetailRow(
              _getIconForType(event.type),
              _getTypeText(event.type),
            ),
            _buildDetailRow(Icons.calendar_today, DateFormat('MMMM d, yyyy').format(date)),
            _buildDetailRow(
                Icons.repeat,
                event.isRecurring ? 'Weekly Recurring Class' : 'Single Class'
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditSingleClassDialog(event: event, date: date);
            },
            child: const Text('Edit This Class'),
          ),
          if (event.isRecurring)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditSeriesDialog(event: event, date: date);
              },
              child: const Text('Edit Series'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  IconData _getIconForType(ClassType type) {
    switch (type) {
      case ClassType.lecture:
        return Icons.school;
      case ClassType.lab:
        return Icons.computer;
      case ClassType.tutorial:
        return Icons.group;
      case ClassType.discussion:
        return Icons.forum;
      case ClassType.seminar:
        return Icons.record_voice_over;
    }
  }

  String _getTypeText(ClassType type) {
    switch (type) {
      case ClassType.lecture:
        return 'Lecture';
      case ClassType.lab:
        return 'Lab Session';
      case ClassType.tutorial:
        return 'Tutorial';
      case ClassType.discussion:
        return 'Discussion';
      case ClassType.seminar:
        return 'Seminar';
    }
  }

  void _showAddClassDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Class', style: GoogleFonts.poppins()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.event, color: Colors.blue),
                title: Text('Single Class'),
                subtitle: Text('Add a one-time class'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddSingleClassDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.repeat, color: Colors.green),
                title: Text('Class Series'),
                subtitle: Text('Add recurring classes'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddClassSeriesDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddSingleClassDialog() {
    _showClassDialog(
      isEditing: false,
      isSeries: false,
    );
  }

  void _showAddClassSeriesDialog() {
    _showClassDialog(
      isEditing: false,
      isSeries: true,
    );
  }

  void _showEditSingleClassDialog({required ClassEvent event, required DateTime date}) {
    _showClassDialog(
      isEditing: true,
      isSeries: false,
      event: event,
      date: date,
    );
  }

  void _showEditSeriesDialog({required ClassEvent event, required DateTime date}) {
    _showClassDialog(
      isEditing: true,
      isSeries: true,
      event: event,
      date: date,
    );
  }

  void _showClassDialog({
    required bool isEditing,
    required bool isSeries,
    ClassEvent? event,
    DateTime? date,
  }) {
    final selectedDate = date ?? _selectedDay!;

    TextEditingController titleController = TextEditingController(text: event?.title ?? '');
    TextEditingController timeController = TextEditingController(text: event?.time ?? '');
    TextEditingController locationController = TextEditingController(text: event?.location ?? '');
    TextEditingController instructorController = TextEditingController(text: event?.instructor ?? '');

    ClassType selectedType = event?.type ?? ClassType.lecture;
    DateTime tempSelectedDate = selectedDate;
    List<int> selectedDays = [selectedDate.weekday];
    int selectedWeeks = 24;

    bool _isSaving = false;
    bool isFormValid = false;

    void validateForm() {
      final bool fieldsFilled = titleController.text.isNotEmpty &&
          timeController.text.isNotEmpty &&
          locationController.text.isNotEmpty &&
          instructorController.text.isNotEmpty;

      final bool daysSelected = !isSeries || selectedDays.isNotEmpty;

      isFormValid = fieldsFilled && daysSelected;
    }

    validateForm();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updateState({bool isSaving = false}) {
            _isSaving = isSaving;
            setDialogState(() {});
            validateForm();
          }

          return AlertDialog(
            title: Text(
              isEditing
                  ? (isSeries ? 'Edit Class Series' : 'Edit This Class')
                  : (isSeries ? 'Add New Class Series' : 'Add Single Class'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Class Title',
                      border: OutlineInputBorder(),
                      errorText: titleController.text.isEmpty ? 'Class title is required' : null,
                    ),
                    onChanged: (value) => updateState(),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Time (e.g., 9:00 AM - 10:30 AM)',
                      border: OutlineInputBorder(),
                      errorText: timeController.text.isEmpty ? 'Time is required' : null,
                    ),
                    onChanged: (value) => updateState(),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Room Number/Location',
                      border: OutlineInputBorder(),
                      errorText: locationController.text.isEmpty ? 'Location is required' : null,
                    ),
                    onChanged: (value) => updateState(),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: instructorController,
                    decoration: InputDecoration(
                      labelText: 'Professor Name',
                      border: OutlineInputBorder(),
                      errorText: instructorController.text.isEmpty ? 'Professor name is required' : null,
                    ),
                    onChanged: (value) => updateState(),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<ClassType>(
                    value: selectedType,
                    onChanged: (ClassType? newValue) {
                      setDialogState(() {
                        selectedType = newValue!;
                      });
                    },
                    items: ClassType.values.map((ClassType type) {
                      return DropdownMenuItem<ClassType>(
                        value: type,
                        child: Text(_getTypeText(type)),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Class Type',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // Show schedule settings only for series
                  if (isSeries) ...[
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'Schedule Settings',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      title: Text('Start Date: ${DateFormat('MMM d, yyyy').format(tempSelectedDate)}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempSelectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempSelectedDate = picked;
                            if (!selectedDays.contains(picked.weekday)) {
                              selectedDays = [picked.weekday];
                            }
                            validateForm();
                          });
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Repeat on Days:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(_getDayName(day)),
                          selected: isSelected,
                          onSelected: isEditing && !isSeries
                              ? null
                              : (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                              selectedDays.sort();
                              validateForm();
                            });
                          },
                        );
                      }),
                    ),
                    if (selectedDays.isEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'Please select at least one day',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    SizedBox(height: 12),
                    Text(
                      'Duration:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedWeeks,
                      onChanged: isEditing && !isSeries
                          ? null
                          : (int? newValue) {
                        setDialogState(() {
                          selectedWeeks = newValue!;
                        });
                      },
                      items: [12, 16, 20, 24, 28, 32].map((weeks) {
                        return DropdownMenuItem<int>(
                          value: weeks,
                          child: Text('$weeks weeks (${(weeks / 4).toStringAsFixed(1)} months)'),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else if (!isEditing) ...[
                    // For single class, show only date selection
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'Class Date',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      title: Text('Date: ${DateFormat('MMM d, yyyy').format(tempSelectedDate)}'),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempSelectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempSelectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
                onPressed: isFormValid && !_isSaving
                    ? () async {
                  if (titleController.text.isNotEmpty &&
                      timeController.text.isNotEmpty &&
                      locationController.text.isNotEmpty &&
                      instructorController.text.isNotEmpty &&
                      (isSeries ? selectedDays.isNotEmpty : true)) {

                    try {
                      updateState(isSaving: true);
                      if (isEditing) {
                        final updatedClass = ClassEvent(
                          id: event!.id,
                          baseClassId: event.baseClassId,
                          title: titleController.text,
                          time: timeController.text,
                          location: locationController.text,
                          instructor: instructorController.text,
                          type: selectedType,
                          isRecurring: event.isRecurring,
                        );

                        if (isSeries) {
                          await _editClassSeries(updatedClass, selectedDate, tempSelectedDate, selectedDays, selectedWeeks);
                        } else {
                          await _editSingleClass(updatedClass, selectedDate, tempSelectedDate);
                        }
                      } else {
                        final newClass = ClassEvent(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          baseClassId: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text,
                          time: timeController.text,
                          location: locationController.text,
                          instructor: instructorController.text,
                          type: selectedType,
                          isRecurring: isSeries,
                        );

                        if (isSeries) {
                          await _addClass(newClass, tempSelectedDate, selectedDays, selectedWeeks);
                        } else {
                          await _addSingleClass(newClass, tempSelectedDate);
                        }
                      }

                      Navigator.pop(context);
                    } catch (e) {
                      updateState(isSaving: false);
                      _showErrorSnackBar('Failed to save class: $e');
                    }
                  }
                }
                    : null,
                child: _isSaving
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : Text(
                  isEditing
                      ? (isSeries ? 'Update Series' : 'Update Class')
                      : (isSeries ? 'Add Series' : 'Add Class'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  void _showDeleteConfirmation(ClassEvent event, DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Class'),
        content: Text('Are you sure you want to delete "${event.title}" on ${DateFormat('MMM d, yyyy').format(date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteClass(event.id, date);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation(ClassEvent event) {
    bool _isDeleting = false;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Delete All Classes'),
              content: Text('Are you sure you want to delete all instances of "${event.title}"?'),
              actions: [
                TextButton(
                  onPressed: _isDeleting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isDeleting ? null : () async {
                    setDialogState(() {
                      _isDeleting = true;
                    });
                    try {
                      await _deleteAllClassInstances(event.baseClassId);
                      _deleteAllInstances(event.baseClassId);
                      Navigator.pop(context);
                      _showSuccessSnackBar('All class instances deleted successfully!');
                    } catch (e) {
                      setDialogState(() {
                        _isDeleting = false;
                      });
                      _showErrorSnackBar('Failed to delete class series: $e');
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: _isDeleting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                      : const Text('Delete All'),
                ),
              ],
            );
          },
        )
    );
  }
}

class ClassEvent {
  final String id;
  final String baseClassId;
  final String title;
  final String time;
  final String location;
  final String instructor;
  final ClassType type;
  final bool isRecurring;

  ClassEvent({
    required this.id,
    required this.baseClassId,
    required this.title,
    required this.time,
    required this.location,
    required this.instructor,
    required this.type,
    this.isRecurring = false,
  });

  ClassEvent copyWith({
    String? id,
    String? baseClassId,
    String? title,
    String? time,
    String? location,
    String? instructor,
    ClassType? type,
    bool? isRecurring,
  }) {
    return ClassEvent(
      id: id ?? this.id,
      baseClassId: baseClassId ?? this.baseClassId,
      title: title ?? this.title,
      time: time ?? this.time,
      location: location ?? this.location,
      instructor: instructor ?? this.instructor,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  Map<String, dynamic> toMap(DateTime date) {
    return {
      'id': id,
      'baseClassId': baseClassId,
      'title': title,
      'time': time,
      'location': location,
      'instructor': instructor,
      'type': type.index,
      'date': Timestamp.fromDate(date),
      'isRecurring': isRecurring,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClassEvent.fromMap(Map<String, dynamic> map) {
    try {
      return ClassEvent(
        id: map['id']?.toString() ?? '',
        baseClassId: map['baseClassId']?.toString() ?? map['id']?.toString().split('_')[0] ?? '',
        title: map['title']?.toString() ?? '',
        time: map['time']?.toString() ?? '',
        location: map['location']?.toString() ?? '',
        instructor: map['instructor']?.toString() ?? '',
        type: ClassType.values[map['type'] is int ? map['type'] : 0],
        isRecurring: map['isRecurring'] ?? false,
      );
    } catch (e) {
      print('Error creating ClassEvent from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}

enum ClassType {
  lecture,
  lab,
  tutorial,
  discussion,
  seminar,
}