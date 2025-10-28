import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  final String? selectedClassroomId;

  const ScheduleScreen({super.key, this.selectedClassroomId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<ClassEvent>> _events = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  String? _userRole;
  bool _isLoading = true;
  List<Map<String, dynamic>> _classrooms = [];
  String? _selectedClassroomId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _currentUserId = _auth.currentUser?.uid;
    _selectedClassroomId = widget.selectedClassroomId;
    _loadUserData();
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedClassroomId != oldWidget.selectedClassroomId) {
      setState(() {
        _selectedClassroomId = widget.selectedClassroomId;
      });
      _loadClasses();
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(_currentUserId!).get();
      final userData = userDoc.data();
      setState(() {
        _userRole = userData?['role'] ?? 'Student';
      });

      await _loadClassrooms();
      await _loadClasses();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClassrooms() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      List<Map<String, dynamic>> classrooms = [];

      if (_userRole == 'Teacher') {
        final teacherClassrooms = await _firestore
            .collection('classrooms')
            .where('createdBy', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in teacherClassrooms.docs) {
          classrooms.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      } else if (_userRole == 'CR') {
        final crClassrooms = await _firestore
            .collection('classrooms')
            .where('cr', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in crClassrooms.docs) {
          classrooms.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      } else if (_userRole == 'Student') {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms =
            List<String>.from(userData?['enrolledClassrooms'] ?? []);

        if (enrolledClassrooms.isNotEmpty) {
          final studentClassrooms = await _firestore
              .collection('classrooms')
              .where(FieldPath.documentId, whereIn: enrolledClassrooms)
              .where('isActive', isEqualTo: true)
              .get();

          for (final doc in studentClassrooms.docs) {
            classrooms.add({
              'id': doc.id,
              ...doc.data(),
            });
          }
        }
      }

      setState(() {
        _classrooms = classrooms;
        if (_selectedClassroomId == null && classrooms.isNotEmpty) {
          _selectedClassroomId = classrooms.first['id'];
        }
      });
    } catch (e) {
      print('Error loading classrooms: $e');
    }
  }

  Future<void> _loadClasses() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      List<ClassEvent> allClasses = [];

      if (_userRole == 'Teacher' || _userRole == 'CR') {
        Query classesQuery = _firestore
            .collection('classes')
            .where('teacherUid', isEqualTo: _currentUserId);

        if (_selectedClassroomId != null && _selectedClassroomId!.isNotEmpty) {
          classesQuery =
              classesQuery.where('classroomId', isEqualTo: _selectedClassroomId);
        }

        final teacherClasses = await classesQuery.get();

        for (final doc in teacherClasses.docs) {
          try {
            final classEvent = ClassEvent.fromMap(doc.data() as Map<String, dynamic>);
            if (_selectedClassroomId == null ||
                classEvent.classroomId == _selectedClassroomId) {
              allClasses.add(classEvent);
            }
          } catch (e) {
            print('Error processing teacher class: $e');
          }
        }
      } else if (_userRole == 'Student') {
        final userDoc =
            await _firestore.collection('users').doc(_currentUserId!).get();
        final userData = userDoc.data();
        final enrolledClassrooms =
            List<String>.from(userData?['enrolledClassrooms'] ?? []);

        final classroomsToLoad =
            _selectedClassroomId != null && _selectedClassroomId!.isNotEmpty
                ? [_selectedClassroomId!]
                : enrolledClassrooms;
        for (final classroomId in classroomsToLoad) {
          try {
            final classroomClasses = await _firestore
                .collection('classes')
                .where('classroomId', isEqualTo: classroomId)
                .get();

            for (final doc in classroomClasses.docs) {
              try {
                final classEvent = ClassEvent.fromMap(doc.data());
                allClasses.add(classEvent);
              } catch (e) {
                print('Error processing enrolled class: $e');
              }
            }
          } catch (e) {
            print('Error loading classroom $classroomId: $e');
          }
        }
      }

      setState(() {
        _events.clear();
        for (final classEvent in allClasses) {
          final key = DateTime(
              classEvent.date.year, classEvent.date.month, classEvent.date.day);
          if (_events.containsKey(key)) {
            _events[key]!.add(classEvent);
          } else {
            _events[key] = [classEvent];
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

  void _onClassroomSelected(String? classroomId) {
    setState(() {
      _selectedClassroomId = classroomId;
    });
    _loadClasses();
  }

  // Update the _canEditClass method in ScheduleScreen to check for classroom teachers
  Future<bool> _canEditClass(ClassEvent event) async {
    if (_userRole == 'Teacher' || _userRole == 'CR') {
      // Check if current user is the creator OR if they are a teacher in the same classroom
      return event.teacherUid == _currentUserId ||
          await _isTeacherInClassroom(event.classroomId);
    }
    return false;
  }

// Add this method to check if user is a teacher in the classroom
  Future<bool> _isTeacherInClassroom(String classroomId) async {
    if (_currentUserId == null) return false;
    if (classroomId.isEmpty) return false;

    try {
      final classroomDoc =
          await _firestore.collection('classrooms').doc(classroomId).get();
      if (classroomDoc.exists) {
        final classroomData = classroomDoc.data() as Map<String, dynamic>;
        final createdBy = classroomData['createdBy'] as String?;
        return createdBy != null && createdBy == _currentUserId;
      }
    } catch (e) {
      print('Error checking classroom creator: $e');
    }

    return false;
  }


  Future<void> _addClassToFirestore(ClassEvent event, DateTime date) async {
    if (_currentUserId == null) {
      _showErrorSnackBar('Please sign in to add classes');
      return;
    }

    if (_userRole != 'Teacher' && _userRole != 'CR') {
      _showErrorSnackBar('Only teachers and CRs can create classes');
      return;
    }

    try {
      String? classroomId;
      Map<String, dynamic>? classroomData;

      if (_selectedClassroomId != null && _selectedClassroomId!.isNotEmpty) {
        final classroomDoc = await _firestore
            .collection('classrooms')
            .doc(_selectedClassroomId!)
            .get();
        if (classroomDoc.exists) {
          classroomId = classroomDoc.id;
          classroomData = classroomDoc.data();
        }
      }

      if (classroomId == null) {
        final userClassrooms = await _firestore
            .collection('classrooms')
            .where('createdBy', isEqualTo: _currentUserId)
            .get();
        if (userClassrooms.docs.isEmpty) {
          _showErrorSnackBar('Please create or select a classroom first.');
          return;
        }
        classroomId = userClassrooms.docs.first.id;
        classroomData = userClassrooms.docs.first.data();
      }

      if (classroomData == null) {
        _showErrorSnackBar('Selected classroom not found.');
        return;
      }


      final classData = {
        ...event.toMap(date),
        'teacherUid': _currentUserId,
        'classroomId': classroomId,
        'classroomName': classroomData['className'],
        'classCode': classroomData['classCode'],
      };

      print('Adding class to Firestore: $classData');
      final docRef = await _firestore.collection('classes').add(classData);

      print('Class added with ID: ${docRef.id}');

      await _loadClasses();
      _showSuccessSnackBar('Class added successfully to ${classroomData!['className']}!');

    } catch (e) {
      print('Error adding class: $e');
      _showErrorSnackBar('Failed to add class: $e');
    }
  }

  Future<void> _addClassSeries(ClassEvent newClass, DateTime startDate,
      List<int> recurringDays, int weeks) async {
    try {
      int totalClassesAdded = 0;

      for (int week = 0; week < weeks; week++) {
        for (int day in recurringDays) {
          DateTime classDate = startDate
              .add(Duration(days: (week * 7) + (day - startDate.weekday) % 7));

          final instanceClass = newClass.copyWith(
            id: '${newClass.id}_${classDate.millisecondsSinceEpoch}',
            baseClassId: newClass.id,
            isRecurring: true,
          );

          await _addClassToFirestore(instanceClass, classDate);
          totalClassesAdded++;
        }
      }

      _showSuccessSnackBar(
          'Class series added successfully! $totalClassesAdded classes scheduled for $weeks weeks.');
    } catch (e) {
      _showErrorSnackBar('Failed to add class series: $e');
    }
  }

  Future<void> _updateClassInFirestore(ClassEvent event, DateTime date) async {
    if (_currentUserId == null) return;
    bool canEdit = await _canEditClass(event);
    if (!canEdit) {
      _showErrorSnackBar('You do not have permission to edit this class.');
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('id', isEqualTo: event.id)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final updateData = event.toMap(date);
        await snapshot.docs.first.reference.update(updateData);
        print('Class updated: ${event.id}');

        await _loadClasses();
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
      final classDoc = await _firestore.collection('classes').where('id', isEqualTo: classId).limit(1).get();
      if (classDoc.docs.isEmpty) {
        print('No class found with id: $classId');
        return;
      }

      final eventToDelete = ClassEvent.fromMap(classDoc.docs.first.data());
      bool canDelete = await _canEditClass(eventToDelete);

      if (!canDelete) {
        _showErrorSnackBar('You do not have permission to delete this class.');
        return; // Important: exit if no permission
      }

      await classDoc.docs.first.reference.delete();
      print('Class deleted: $classId');

      await _loadClasses();
      _showSuccessSnackBar('Class deleted successfully!');
    } catch (e) {
      print('Error deleting class: $e');
      throw e;
    }
  }

  Future<void> _rescheduleClass(ClassEvent originalClass, DateTime newDate,
      String newTime, String newLocation) async {
    bool canReschedule = await _canEditClass(originalClass);
    if (!canReschedule) {
      _showErrorSnackBar('You do not have permission to reschedule this class.');
      return;
    }
    try {
      await _firestore.collection('rescheduled_classes').add({
        'originalClassId': originalClass.id,
        'className': originalClass.title,
        'instructor': originalClass.instructor,
        'originalDate': Timestamp.fromDate(originalClass.date),
        'originalTime': originalClass.time,
        'originalLocation': originalClass.location,
        'newDate': Timestamp.fromDate(newDate),
        'newTime': newTime,
        'newLocation': newLocation,
        'teacherUid': _currentUserId,
        'classroomId': originalClass.classroomId,
        'classroomName': originalClass.classroomName,
        'classCode': originalClass.classCode,
        'rescheduledAt': FieldValue.serverTimestamp(),
      });

      final updatedClass = originalClass.copyWith(
        date: newDate,
        time: newTime,
        location: newLocation,
      );

      await _updateClassInFirestore(updatedClass, newDate);

      _showSuccessSnackBar(
          'Class rescheduled successfully! Students will be notified.');
    } catch (e) {
      print('Error rescheduling class: $e');
      _showErrorSnackBar('Failed to reschedule class: $e');
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  List<ClassEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
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
          : Column(
              children: [
                if (_classrooms.isNotEmpty) ...[
                  Card(
                    margin: EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Classroom Filter',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedClassroomId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Show All',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All My Classrooms',
                              style: GoogleFonts.poppins(),
                              overflow: TextOverflow.ellipsis),
                        ),
                        ..._classrooms
                            .map<DropdownMenuItem<String>>((classroom) {
                          return DropdownMenuItem<String>(
                            value: classroom['id'],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      classroom['className'] as String,
                                      style: GoogleFonts.poppins(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: _onClassroomSelected,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: TabBarView( // Added Expanded to constrain TabBarView
              controller: _tabController,
              children: [
                // Calendar View
                SingleChildScrollView(
                  child: Column(children: [
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
                    events.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(), // Important to avoid nested scroll issues
                      shrinkWrap: true, // Important for ListView inside SingleChildScrollView
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          return _buildClassItem(events[index], _selectedDay!);
                        },
                      ),
                  ],
                ),),
                // List View
                SingleChildScrollView(
                  child: Column(
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
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadClasses,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),
                    if (_events.isEmpty)
                      _buildEmptyState()
                    else
                      ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _getUpcomingWeekEvents(),
                      ),
                  ],
                ),
                ),
              ],
            ),),
      ]),

      floatingActionButton: (_userRole == 'Teacher' || _userRole == 'CR')
          ? FloatingActionButton(
              onPressed: () {
                _showAddClassDialog();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
          if (_userRole == 'Teacher' || _userRole == 'CR')
            Text(
              'Tap + to add your first class',
              style: GoogleFonts.poppins(
                color: Colors.grey,
              ),
            )
          else
            Text(
              'Join a classroom to see classes',
              style: GoogleFonts.poppins(
                color: Colors.grey,
              ),
            ),
        ],
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
        trailing: FutureBuilder<bool>(
          future: _canEditClass(event),
          builder:
              (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit_single') {
                    _showEditSingleClassDialog(event: event, date: date);
                  } else if (value == 'edit_series' && event.isRecurring) {
                    _showEditSeriesDialog(
                        event: event, date: date);
                  } else if (value == 'reschedule') {
                    _showRescheduleDialog(
                        event: event, date: date);
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
                      value: 'reschedule',
                      child: Row(
                        children: [
                          Icon(Icons.update, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Reschedule'),
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
              );
            }
            return const SizedBox.shrink();
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
            if (event.classroomName.isNotEmpty)
              _buildDetailRow(Icons.school, 'Classroom: ${event.classroomName}'),
            if (event.classCode.isNotEmpty)
              _buildDetailRow(Icons.code, 'Class Code: ${event.classCode}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FutureBuilder<bool>(
            future: _canEditClass(event),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditSingleClassDialog(event: event, date: date);
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }
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
                subtitle: Text('Add recurring classes for multiple weeks'),
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

  void _showRescheduleDialog({required ClassEvent event, required DateTime date}) {
    TextEditingController timeController = TextEditingController(text: event.time);
    TextEditingController locationController = TextEditingController(text: event.location);
    DateTime tempSelectedDate = date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Reschedule Class', style: GoogleFonts.poppins()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reschedule "${event.title}"',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    title: Text('New Date: ${DateFormat('MMM d, yyyy').format(tempSelectedDate)}'),
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
                  SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'New Time (e.g., 9:00 AM - 10:30 AM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'New Room Number/Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (timeController.text.isNotEmpty && locationController.text.isNotEmpty) {
                      Navigator.pop(
                          context);
                    await _rescheduleClass(event, tempSelectedDate, timeController.text, locationController.text);
                  }
                },
                child: const Text('Reschedule'),
              ),
            ],
          );
        },
      ),
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
                            label:
                                Text(_getDayName(day)),
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
                          child: Text(
                              '$weeks weeks (${(weeks / 4).toStringAsFixed(1)} months)'),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else if (!isEditing) ...[
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
                          date: event.date,
                          teacherUid: event.teacherUid,
                          classroomId: event.classroomId,
                          classroomName: event.classroomName,
                          classCode: event.classCode,
                        );

                        if (isSeries) {
                          await _editClassSeries(updatedClass, selectedDate,
                              tempSelectedDate, selectedDays, selectedWeeks);
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
                          date: tempSelectedDate,
                          teacherUid: _currentUserId!,
                          classroomId: '',
                          classroomName: '',
                          classCode: '',
                        );

                        if (isSeries) {
                          await _addClassSeries(newClass, tempSelectedDate,
                              selectedDays, selectedWeeks);
                        } else {
                          await _addClassToFirestore(newClass, tempSelectedDate);
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

  Future<void> _editClassSeries(
      ClassEvent updatedClass,
      DateTime originalDate,
      DateTime newDate,
      List<int> recurringDays,
      int weeks) async {
    try {
      await _deleteAllClassInstances(updatedClass.baseClassId);

      final updatedBaseClass = updatedClass.copyWith(
        id: updatedClass.baseClassId,
        isRecurring: true,
      );

      await _addClassSeries(updatedBaseClass, newDate, recurringDays, weeks);
      _showSuccessSnackBar(
          'Class series updated successfully! All instances have been rescheduled.');
    } catch (e) {
      _showErrorSnackBar('Failed to update class series: $e');
    }
  }

  Future<void> _editSingleClass(
      ClassEvent updatedClass, DateTime originalDate, DateTime newDate) async {
    try {
      await _deleteClassFromFirestore(updatedClass.id);

      String newId;
      if (updatedClass.isRecurring) {
        newId =
            '${updatedClass.baseClassId}_${newDate.millisecondsSinceEpoch}';
      } else {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        newId = 'single_$tempId';
      }

      final updatedInstance = updatedClass.copyWith(
        id: newId,
        baseClassId: updatedClass.isRecurring ? updatedClass.baseClassId : newId,
      );

      await _addClassToFirestore(updatedInstance, newDate);
      _showSuccessSnackBar('Class updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to update class: $e');
    }
  }

  Future<void> _deleteAllClassInstances(String baseClassId) async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('baseClassId', isEqualTo: baseClassId) // Find all instances
          .get();

      if (snapshot.docs.isEmpty) {
        print('No class series found for baseClassId: $baseClassId');
        return;
      }

      final batch = _firestore.batch();
      bool hasPermission = true;

      for (final doc in snapshot.docs) {
        final event = ClassEvent.fromMap(doc.data());
        if (!await _canEditClass(event)) {
          hasPermission = false;
          break;
        }
        batch.delete(doc.reference);
      }

      if (!hasPermission) {
        _showErrorSnackBar('You do not have permission to delete this series.');
        return;
      }

      await batch.commit();
      print('Deleted ${snapshot.docs.length} instances of class: $baseClassId');

      await _loadClasses();
    } catch (e) {
      print('Error deleting class series: $e');
      throw e;
    }
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
              await _deleteClassFromFirestore(event.id); // Snack bar is now inside this function
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

  void _showEditOptionsDialog(ClassEvent event, DateTime date) {
    if (event.isRecurring) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Recurring Class'),
          content: Text(
              'Do you want to edit only this instance or the entire series?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditSingleClassDialog(event: event, date: date);
              },
              child: Text('Edit This Instance'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditSeriesDialog(event: event, date: date);
              },
              child: Text('Edit Series'),
            ),
          ],
        ),
      );
    } else {
      _showEditSingleClassDialog(event: event, date: date);
    }
  }

  void _showDeleteOptionsDialog(ClassEvent event, DateTime date) {
    if (event.isRecurring) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Recurring Class'),
          content: Text(
              'Do you want to delete only this instance or the entire series?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(event, date);
              },
              child: Text('Delete This Instance'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteAllConfirmation(event);
              },
              child: Text('Delete Series'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else {
      _showDeleteConfirmation(event, date);
    }
  }

  Widget _buildEditButton(ClassEvent event, DateTime date) {
    return FutureBuilder<bool>(
        future: _canEditClass(event),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == true) {
            return IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditOptionsDialog(event, date),
              tooltip: 'Edit Class',
            );
          }
          return SizedBox.shrink();
        });
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
  final DateTime date;
  final String teacherUid;
  final String classroomId;
  final String classroomName;
  final String classCode;

  ClassEvent({
    required this.id,
    required this.baseClassId,
    required this.title,
    required this.time,
    required this.location,
    required this.instructor,
    required this.type,
    this.isRecurring = false,
    required this.date,
    required this.teacherUid,
    required this.classroomId,
    required this.classroomName,
    required this.classCode,
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
    DateTime? date,
    String? teacherUid,
    String? classroomId,
    String? classroomName,
    String? classCode,
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
      date: date ?? this.date,
      teacherUid: teacherUid ?? this.teacherUid,
      classroomId: classroomId ?? this.classroomId,
      classroomName: classroomName ?? this.classroomName,
      classCode: classCode ?? this.classCode,
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
      'teacherUid': teacherUid,
      'classroomId': classroomId,
      'classroomName': classroomName,
      'classCode': classCode,
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
        date: (map['date'] as Timestamp).toDate(),
        teacherUid: map['teacherUid']?.toString() ?? '',
        classroomId: map['classroomId']?.toString() ?? '',
        classroomName: map['classroomName']?.toString() ?? '',
        classCode: map['classCode']?.toString() ?? '',
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

extension RoleBasedEditing on String {
  bool get canEditSchedule {
    return this == 'Teacher' || this == 'CR';
  }
}




