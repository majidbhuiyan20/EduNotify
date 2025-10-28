import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
import '../ui/add_class_room_screen.dart';
import '../ui/create_class_room_screen.dart';
import '../ui/role_selection_ui.dart';
import 'schedule_screen.dart';
import 'assignment_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

// A function type for handling navigation from child widgets
typedef void GoToPageCallback(int pageIndex);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  late List<Widget> _screens;
  String? _userRole;
  bool _isLoading = true;
  String? _selectedClassroomId;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _checkUserRole();
  }

  void _initializeScreens() {
    _screens = [
      DashboardScreen(
        onNavigate: _navigateToPage,
        userRole: _userRole,
        onClassroomSelected: _onClassroomSelected,
        selectedClassroomId: _selectedClassroomId,
      ),
      ScheduleScreen(selectedClassroomId: _selectedClassroomId),
      const AssignmentScreen(),
      const NotificationScreen(),
      SettingsScreen(),
    ];
  }

  void _onClassroomSelected(String? classroomId) {
    setState(() {
      _selectedClassroomId = classroomId;
    });
    _updateScreens();
  }

  Future<void> _checkUserRole() async {
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _userRole = userData?['role'];
          _isLoading = false;
        });

        if (_userRole == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
            );
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
          );
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
    _updateScreens();
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _updateScreens() {
    setState(() {
      _screens = [
        DashboardScreen(
          onNavigate: _navigateToPage,
          userRole: _userRole,
          onClassroomSelected: _onClassroomSelected,
          selectedClassroomId: _selectedClassroomId,
        ),
        ScheduleScreen(selectedClassroomId: _selectedClassroomId),
        const AssignmentScreen(),
        const NotificationScreen(),
        SettingsScreen(),
      ];
    });
  }

  void _showJoinClassDialog() {
    TextEditingController classCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Class', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the class code provided by your teacher',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: classCodeController,
              decoration: InputDecoration(
                labelText: 'Class Code',
                border: OutlineInputBorder(),
                hintText: 'e.g., MATH1012024',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final classCode = classCodeController.text.trim();
              if (classCode.isNotEmpty) {
                Navigator.pop(context);
                await _joinClass(classCode);
              }
            },
            child: const Text('Join Class'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinClass(String classCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final classroomQuery = await FirebaseFirestore.instance
          .collection('classrooms')
          .where('classCode', isEqualTo: classCode)
          .where('isActive', isEqualTo: true)
          .get();

      if (classroomQuery.docs.isEmpty) {
        _showSnackBar('Classroom not found. Please check the class code.', Colors.red);
        return;
      }

      final classroomDoc = classroomQuery.docs.first;
      final classroomData = classroomDoc.data();
      final students = List<String>.from(classroomData['students'] ?? []);

      if (students.contains(user.uid)) {
        _showSnackBar('You are already enrolled in this classroom.', Colors.orange);
        return;
      }

      await classroomDoc.reference.update({
        'students': FieldValue.arrayUnion([user.uid])
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'enrolledClassrooms': FieldValue.arrayUnion([classroomDoc.id]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar('Successfully joined classroom!', Colors.green);
      setState(() {});

    } catch (e) {
      _showSnackBar('Error joining classroom: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _navigateToCreateClassroom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateClassRoomScreen()),
    ).then((_) {
      setState(() {});
    });
  }

  void _navigateToAddClassroom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddClassRoomScreen()),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...', style: GoogleFonts.poppins()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
        title: Text(
          'Edu Notify',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinClassDialog,
            tooltip: 'Join Class',
          ),
        ],
      )
          : null,

      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.75, // Responsive width
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: Text(
                        user?.displayName?.substring(0, 1) ?? 'U',
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user?.displayName ?? 'User Name',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? 'user@email.com',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                            ),
                          ),
                          if (_userRole != null) ...[
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                _userRole!,
                                style: GoogleFonts.poppins(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text('Dashboard', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('Schedule', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: Text('Assignments', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text('Notifications', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text('Settings', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 4;
                });
                Navigator.pop(context);
              },
            ),

            if (_userRole == 'Teacher' || _userRole == 'CR') ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: Text('Create Classroom', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCreateClassroom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text('Add Classroom', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddClassroom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text('Join Class', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _showJoinClassDialog();
                },
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text('Logout', style: GoogleFonts.poppins()),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                      (route) => false,
                );
              },
            ),
            if (_userRole != 'Teacher' && _userRole != 'CR')
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text('Join Class', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _showJoinClassDialog();
                },
              ),
          ],
        ),
      ),

      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),

      floatingActionButton: _currentIndex == 0
          ? (_userRole == 'Teacher' || _userRole == 'CR')
          ? FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Classroom Management'),
              content: Text('Choose an option'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToCreateClassroom();
                  },
                  child: Text('Create Classroom'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToAddClassroom();
                  },
                  child: Text('Add Classroom'),
                ),
              ],
            ),
          );
        },
        icon: Icon(Icons.add),
        label: Text('Classroom'),
      )
          : (_userRole == 'Student')
          ? FloatingActionButton.extended(
        onPressed: _showJoinClassDialog,
        icon: const Icon(Icons.group_add),
        label: const Text('Join Classroom'),
      )
          : null
          : null,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final GoToPageCallback onNavigate;
  final String? userRole;
  final Function(String?) onClassroomSelected;
  final String? selectedClassroomId;

  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.userRole,
    required this.onClassroomSelected,
    required this.selectedClassroomId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ClassEvent> _todayClasses = [];
  List<ClassEvent> _tomorrowClasses = [];
  List<ClassEvent> _rescheduledClasses = [];
  bool _isLoading = true;
  String _displayTitle = "Today's Classes";
  List<Map<String, dynamic>> _classrooms = [];
  String? _selectedClassroomId;
  List<Map<String, dynamic>> _recentNotifications = [];

  @override
  void initState() {
    super.initState();
    _selectedClassroomId = widget.selectedClassroomId;
    _loadClassrooms();
    _loadClasses();
    _loadRecentNotifications();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedClassroomId != oldWidget.selectedClassroomId) {
      _selectedClassroomId = widget.selectedClassroomId;
      _loadClasses();
      _loadRecentNotifications();
    }
  }

  Future<void> _loadClassrooms() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      List<Map<String, dynamic>> classrooms = [];

      if (widget.userRole == 'Teacher' || widget.userRole == 'CR') {
        // For teachers and CRs, show both created and joined classrooms
        final teacherClassrooms = await _firestore
            .collection('classrooms')
            .where('createdBy', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

        if (enrolledClassrooms.isNotEmpty) {
          final joinedClassrooms = await _firestore
              .collection('classrooms')
              .where(FieldPath.documentId, whereIn: enrolledClassrooms)
              .where('isActive', isEqualTo: true)
              .get();

          for (final doc in joinedClassrooms.docs) {
            classrooms.add({
              'id': doc.id,
              ...doc.data(),
              'isJoined': true, // Mark as joined classroom
            });
          }
        }

        for (final doc in teacherClassrooms.docs) {
          classrooms.add({
            'id': doc.id,
            ...doc.data(),
            'isCreated': true, // Mark as created classroom
          });
        }
      } else if (widget.userRole == 'Student') {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

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
          widget.onClassroomSelected(_selectedClassroomId);
        }
      });
    } catch (e) {
      print('Error loading classrooms: $e');
    }
  }

  Future<void> _loadClasses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      print('Loading classes for user: ${user.uid}');

      List<ClassEvent> allClasses = [];

      if (widget.userRole == 'Teacher' || widget.userRole == 'CR') {
        Query classesQuery = _firestore
            .collection('classes')
            .where('teacherUid', isEqualTo: user.uid);

        if (_selectedClassroomId != null && _selectedClassroomId!.isNotEmpty) {
          classesQuery = classesQuery.where('classroomId', isEqualTo: _selectedClassroomId);
        }

        final teacherClasses = await classesQuery.get();

        for (final doc in teacherClasses.docs) {
          try {
            final classEvent = ClassEvent.fromMap(doc.data() as Map<String, dynamic>);
            allClasses.add(classEvent);
          } catch (e) {
            print('Error processing teacher class: $e');
          }
        }
      } else if (widget.userRole == 'Student') {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

        final classroomsToLoad = _selectedClassroomId != null && _selectedClassroomId!.isNotEmpty
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

      // Load rescheduled classes
      final rescheduledClasses = await _firestore
          .collection('rescheduled_classes')
          .where('newDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      List<ClassEvent> todayClasses = [];
      List<ClassEvent> tomorrowClasses = [];
      List<ClassEvent> rescheduledClassList = [];

      // Process rescheduled classes
      for (final doc in rescheduledClasses.docs) {
        try {
          final data = doc.data();
          final originalClass = ClassEvent(
            id: data['originalClassId'] ?? '',
            baseClassId: data['originalClassId'] ?? '',
            title: data['className'] ?? 'Class',
            time: data['newTime'] ?? '',
            location: data['newLocation'] ?? '',
            instructor: data['instructor'] ?? '',
            type: ClassType.lecture,
            isRecurring: false,
            date: (data['newDate'] as Timestamp).toDate(),
            teacherUid: data['teacherUid'] ?? '',
            classroomId: data['classroomId'] ?? '',
            classroomName: data['classroomName'] ?? '',
            classCode: data['classCode'] ?? '',
          );
          rescheduledClassList.add(originalClass);
        } catch (e) {
          print('Error processing rescheduled class: $e');
        }
      }

      // Filter rescheduled classes by selected classroom
      List<ClassEvent> filteredRescheduledClasses;
      if (_selectedClassroomId != null && _selectedClassroomId!.isNotEmpty) {
        filteredRescheduledClasses = rescheduledClassList
            .where((c) => c.classroomId == _selectedClassroomId)
            .toList();
      } else {
        // If no classroom is selected, check against all classrooms the user is in.
        final userClassroomIds = _classrooms.map((c) => c['id'] as String).toSet();
        filteredRescheduledClasses = rescheduledClassList
            .where((c) => userClassroomIds.contains(c.classroomId)).toList();
      }

      // Filter classes by date
      for (final classEvent in allClasses) {
        try {
          final classDate = classEvent.date;
          final classDateOnly = DateTime(classDate.year, classDate.month, classDate.day);

          if (classDateOnly.isAtSameMomentAs(today)) {
            todayClasses.add(classEvent);
          } else if (classDateOnly.isAtSameMomentAs(tomorrow)) {
            tomorrowClasses.add(classEvent);
          }
        } catch (e) {
          print('Error processing class date: $e');
        }
      }

      // Filter out past rescheduled classes from the main list.
      final nowDateTime = DateTime.now();
      rescheduledClassList.removeWhere((event) {
        final eventDate = event.date;
        final eventEndTime = _parseEndTime(event.time);

        if (eventEndTime == null) {
          // If we can't parse end time, keep it for safety, or you might decide to remove it.
          // For now, let's assume it's valid if the date is today or in the future.
          return eventDate.isBefore(today);
        }

        final eventEndDateTime = DateTime(eventDate.year, eventDate.month, eventDate.day, eventEndTime.hour, eventEndTime.minute);

        // The event is in the past if its end time is before the current time.
        return eventEndDateTime.isBefore(nowDateTime);
      });

      // Filter out past classes for today
      final currentTime = TimeOfDay.fromDateTime(now);
      final filteredTodayClasses = todayClasses.where((classEvent) {
        final classEndTime = _parseEndTime(classEvent.time);
        return classEndTime != null && _isTimeAfter(classEndTime, currentTime);
      }).toList();

      // Filter out past classes for today
      // final currentTime = TimeOfDay.fromDateTime(now);
      // final filteredTodayClasses = todayClasses.where((classEvent) {
      //   final classEndTime = _parseEndTime(classEvent.time);
      //   return classEndTime != null && _isTimeAfter(classEndTime, currentTime);
      // }).toList();

      setState(() {
        _todayClasses = filteredTodayClasses;
        _tomorrowClasses = tomorrowClasses;
        _rescheduledClasses = filteredRescheduledClasses;
        _isLoading = false;

        // Set display title based on available classes
        if (_todayClasses.isNotEmpty) {
          _displayTitle = "Today's Classes";
        } else if (_tomorrowClasses.isNotEmpty) {
          _displayTitle = "Tomorrow's Classes";
        } else if (_rescheduledClasses.isNotEmpty) {
          _displayTitle = "Rescheduled Classes";
        } else {
          _displayTitle = "My Classes";
        }
      });

    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      List<Map<String, dynamic>> notifications = [];

      // Load assignment notifications
      final assignmentNotifications = await _firestore
          .collection('assignments')
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('dueDate', descending: false)
          .limit(3)
          .get();

      for (final doc in assignmentNotifications.docs) {
        final data = doc.data();
        notifications.add({
          'type': 'assignment',
          'title': 'New Assignment: ${data['title']}',
          'description': 'Due: ${DateFormat('MMM d, yyyy').format((data['dueDate'] as Timestamp).toDate())}',
          'icon': Icons.assignment,
          'color': Colors.orange,
          'timestamp': data['createdAt'] ?? Timestamp.now(),
        });
      }

      // Load rescheduled class notifications
      final rescheduledNotifications = await _firestore
          .collection('rescheduled_classes')
          .where('newDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('newDate', descending: false)
          .limit(3)
          .get();

      for (final doc in rescheduledNotifications.docs) {
        final data = doc.data();
        notifications.add({
          'type': 'rescheduled',
          'title': 'Class Rescheduled: ${data['className']}',
          'description': 'New time: ${data['newTime']} on ${DateFormat('MMM d, yyyy').format((data['newDate'] as Timestamp).toDate())}',
          'icon': Icons.schedule,
          'color': Colors.blue,
          'timestamp': data['createdAt'] ?? Timestamp.now(),
        });
      }

      // Sort notifications by timestamp
      notifications.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

      // Take only the latest 3 notifications
      if (notifications.length > 3) {
        notifications = notifications.sublist(0, 3);
      }

      setState(() {
        _recentNotifications = notifications;
      });
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  void _onClassroomSelected(String? classroomId) {
    setState(() {
      _selectedClassroomId = classroomId;
    });
    widget.onClassroomSelected(classroomId);
    _loadClasses();
    _loadRecentNotifications();
  }

  Widget _buildRoleBasedActions() {
    if (widget.userRole != null) {
      return const SizedBox.shrink();
    }

    return _buildActionCard(
      icon: Icons.person,
      title: 'Select Role',
      color: Colors.orange,
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 20,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final timePart = timeString.split(' - ').first;
      final format = timePart.contains('AM') || timePart.contains('PM')
          ? DateFormat('h:mm a')
          : DateFormat('HH:mm');
      final dateTime = format.parse(timePart);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      print('Error parsing time: $timeString - $e');
      return null;
    }
  }

  TimeOfDay? _parseEndTime(String timeString) {
    try {
      if (timeString.contains(' - ')) {
        final timePart = timeString.split(' - ').last;
        final format = timePart.contains('AM') || timePart.contains('PM')
            ? DateFormat('h:mm a')
            : DateFormat('HH:mm');
        final dateTime = format.parse(timePart);
        return TimeOfDay.fromDateTime(dateTime);
      }
      return _parseTime(timeString);
    } catch (e) {
      return null;
    }
  }

  bool _isTimeAfter(TimeOfDay classTime, TimeOfDay currentTime) {
    if (classTime.hour > currentTime.hour) return true;
    if (classTime.hour == currentTime.hour && classTime.minute > currentTime.minute) return true;
    return false;
  }

  List<ClassEvent> get _displayClasses {
    if (_todayClasses.isNotEmpty) {
      return _todayClasses;
    } else if (_tomorrowClasses.isNotEmpty) {
      return _tomorrowClasses;
    } else if (_rescheduledClasses.isNotEmpty) {
      return _rescheduledClasses;
    }
    return [];
  }

  String get _classCountText {
    if (_todayClasses.isNotEmpty) {
      return '${_todayClasses.length} ${_todayClasses.length == 1 ? 'Class' : 'Classes'}';
    } else if (_tomorrowClasses.isNotEmpty) {
      return '${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'Class' : 'Classes'}';
    } else if (_rescheduledClasses.isNotEmpty) {
      return '${_rescheduledClasses.length} Rescheduled';
    } else {
      return 'No Classes';
    }
  }

  Color get _classCountColor {
    if (_todayClasses.isNotEmpty) {
      return Colors.blue;
    } else if (_tomorrowClasses.isNotEmpty) {
      return Colors.orange;
    } else if (_rescheduledClasses.isNotEmpty) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(user),
          const SizedBox(height: 24),

          _buildRoleBasedActions(),

          if (_classrooms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildClassroomSelector(),
            const SizedBox(height: 16),
          ],

          if (widget.userRole == 'Teacher' || widget.userRole == 'CR') ...[
            const SizedBox(height: 16),
            _buildMyClassroomsSection(),
          ],

          if (widget.userRole == 'Student') ...[
            const SizedBox(height: 16),
            _buildStudentClassroomsSection(),
          ],

          const SizedBox(height: 24),

          if (_rescheduledClasses.isNotEmpty) ...[
            _buildRescheduledClassesCard(),
            const SizedBox(height: 24),
          ],

          _buildClassesCard(),
          const SizedBox(height: 24),

          _buildQuickActions(),
          const SizedBox(height: 24),

          if (_recentNotifications.isNotEmpty) ...[
            _buildNotificationsCard(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildClassroomSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Select Classroom',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedClassroomId,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select a classroom',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Classrooms', style: GoogleFonts.poppins()),
                ),
                ..._classrooms.map<DropdownMenuItem<String>>((classroom) {
                  return DropdownMenuItem<String>(
                    value: classroom['id'] as String?,
                    child: Text(
                      '${classroom['className']} (${classroom['classCode']})',
                      style: GoogleFonts.poppins(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
              ],
              onChanged: _onClassroomSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${user?.displayName?.split(' ').first ?? 'User'}! 👋',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoading
              ? 'Loading your schedule...'
              : _getGreetingMessage(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),

        if (widget.userRole != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(widget.userRole!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getRoleColor(widget.userRole!)),
            ),
            child: Text(
              widget.userRole!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _getRoleColor(widget.userRole!),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        if (!_isLoading) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMyClassroomsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "My Classrooms",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('classrooms')
              .where('createdBy', isEqualTo: user.uid)
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyClassroomsState('You have not created any classrooms yet.');
            }

            final classrooms = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classrooms.length,
              itemBuilder: (context, index) {
                final classroom = classrooms[index];
                final data = classroom.data() as Map<String, dynamic>;
                return _buildClassroomListItem(data, classroom.id, true, false);
              },
            );
          },
        ),

        // Show joined classrooms for CR/Teacher
        StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

            // Filter out classrooms that the user created
            final joinedClassrooms = _classrooms.where((classroom) =>
            enrolledClassrooms.contains(classroom['id']) && classroom['createdBy'] != user.uid).toList();

            if (joinedClassrooms.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  "Joined Classrooms",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: joinedClassrooms.length,
                  itemBuilder: (context, index) {
                    final classroom = joinedClassrooms[index];
                    return _buildClassroomListItem(classroom, classroom['id'], false, true);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStudentClassroomsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "My Enrolled Classrooms",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return _buildEmptyClassroomsState('You are not enrolled in any classrooms yet.');
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

            if (enrolledClassrooms.isEmpty) {
              return _buildEmptyClassroomsState('You are not enrolled in any classrooms yet.');
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('classrooms')
                  .where(FieldPath.documentId, whereIn: enrolledClassrooms)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, classroomSnapshot) {
                if (classroomSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!classroomSnapshot.hasData || classroomSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyClassroomsState('No active classrooms found.');
                }

                final classrooms = classroomSnapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: classrooms.length,
                  itemBuilder: (context, index) {
                    final classroom = classrooms[index];
                    final data = classroom.data() as Map<String, dynamic>;
                    return _buildClassroomListItem(data, classroom.id, false, false);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildClassroomListItem(Map<String, dynamic> data, String classroomId, bool isCreated, bool isJoined) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCreated
              ? Colors.blue.withOpacity(0.2)
              : isJoined
              ? Colors.orange.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
          child: Icon(
            isCreated ? Icons.school : Icons.group,
            color: isCreated ? Colors.blue : isJoined ? Colors.orange : Colors.green,
          ),
        ),
        title: Text(
            data['className'],
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)
        ),
        subtitle: Text(
          isCreated
              ? 'Class Code: ${data['classCode']} (Created by you)'
              : isJoined
              ? 'Class Code: ${data['classCode']} (Joined)'
              : 'Created by: ${data['teacherName'] ?? 'Teacher'}',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        trailing: (isCreated || isJoined)
            ? IconButton(
          icon: Icon(Icons.content_copy, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: data['classCode']));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Class code copied to clipboard!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          tooltip: 'Copy Class Code',
        )
            : null,
        onTap: () {
          _showClassroomDetails(data, classroomId, isCreated, isJoined);
        },
      ),
    );
  }

  Widget _buildEmptyClassroomsState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.school_outlined, size: 48, color: Colors.grey[300]),
              SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.poppins(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClassroomDetails(Map<String, dynamic> classroomData, String classroomId, bool isCreated, bool isJoined) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          classroomData['className'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClassroomDetailRow(Icons.code, 'Class Code: ${classroomData['classCode']}'),
            _buildClassroomDetailRow(Icons.person, 'Teacher: ${classroomData['teacherName'] ?? 'Not specified'}'),
            _buildClassroomDetailRow(Icons.description, 'Subject: ${classroomData['subject'] ?? 'Not specified'}'),
            _buildClassroomDetailRow(Icons.group, 'Students: ${List.from(classroomData['students'] ?? []).length}'),
            if (classroomData['description'] != null)
              _buildClassroomDetailRow(Icons.info, 'Description: ${classroomData['description']}'),
            if (isCreated)
              _buildClassroomDetailRow(Icons.star, 'Status: Classroom Creator'),
            if (isJoined && !isCreated)
              _buildClassroomDetailRow(Icons.group, 'Status: Joined Classroom'),
          ],
        ),
        actions: [
          if (isCreated || isJoined)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: classroomData['classCode']));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Class code copied to clipboard!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              },
              child: Text('Copy Class Code'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRescheduledClassesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📅 Rescheduled Classes",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    '${_rescheduledClasses.length} Updated',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._rescheduledClasses.map((classEvent) => _buildRescheduledClassItem(classEvent)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduledClassItem(ClassEvent classEvent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.update, color: Colors.purple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classEvent.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${classEvent.time} • ${classEvent.location}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(classEvent.date),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesCard() {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    _classCountText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _classCountColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_displayClasses.isEmpty)
              _buildEmptyClassesState()
            else
              ..._buildClassList(),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onNavigate(1);
                },
                icon: const Icon(Icons.schedule, size: 20),
                label: Text(
                  'View Full Schedule',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 150,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildClassItemShimmer(),
            const Divider(),
            _buildClassItemShimmer(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassItemShimmer() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 180,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyClassesState() {
    return Column(
      children: [
        Icon(
          Icons.school_outlined,
          size: 64,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          'No upcoming classes',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join a classroom to see scheduled classes',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildClassList() {
    return _displayClasses.map((classEvent) {
      return Column(
        children: [
          _buildClassItem(classEvent),
          if (_displayClasses.indexOf(classEvent) != _displayClasses.length - 1)
            const Divider(),
        ],
      );
    }).toList();
  }

  Widget _buildClassItem(ClassEvent classEvent) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getColorForType(classEvent.type).withOpacity(0.2),
        child: Icon(_getIconForType(classEvent.type), color: _getColorForType(classEvent.type)),
      ),
      title: Text(
        classEvent.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${classEvent.time} • ${classEvent.location}',
        style: GoogleFonts.poppins(),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        widget.onNavigate(1);
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        if (widget.userRole == 'Teacher' || widget.userRole == 'CR') ...[
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.add,
              title: 'Add Class',
              color: Colors.green,
              onTap: () {
                widget.onNavigate(1);
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.assignment,
            title: 'Assignments',
            color: Colors.orange,
            onTap: () {
              widget.onNavigate(2);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.notifications,
            title: 'Notifications',
            color: Colors.purple,
            onTap: () {
              widget.onNavigate(3);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 20,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Notifications",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    '${_recentNotifications.length} New',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._recentNotifications.map((notification) =>
                _buildNotificationItem(
                  notification['title'] as String,
                  notification['description'] as String,
                  notification['icon'] as IconData,
                  notification['color'] as Color,
                )
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.onNavigate(3);
                },
                child: Text(
                  'View All Notifications',
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String subtitle, IconData icon, Color color) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: GoogleFonts.poppins()),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
        if (_recentNotifications.indexOf(_recentNotifications.firstWhere((n) => n['title'] == title)) != _recentNotifications.length - 1)
          const Divider(),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Teacher':
        return Colors.red;
      case 'CR':
        return Colors.orange;
      case 'Student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getGreetingMessage() {
    if (_todayClasses.isNotEmpty) {
      return 'You have ${_todayClasses.length} ${_todayClasses.length == 1 ? 'class' : 'classes'} today.';
    } else if (_tomorrowClasses.isNotEmpty) {
      return 'No more classes today. ${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'class' : 'classes'} scheduled for tomorrow.';
    } else if (_rescheduledClasses.isNotEmpty) {
      return 'You have ${_rescheduledClasses.length} rescheduled ${_rescheduledClasses.length == 1 ? 'class' : 'classes'}.';
    } else {
      return 'No upcoming classes. Join a classroom to see classes!';
    }
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