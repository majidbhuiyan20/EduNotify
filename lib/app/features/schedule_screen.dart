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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _initializeEvents();
  }

  void _initializeEvents() {
    final now = DateTime.now();

    // Add some sample events
    _events[DateTime(now.year, now.month, now.day)] = [
      ClassEvent(
        title: 'Mathematics 101',
        time: '9:00 AM - 10:30 AM',
        location: 'Room 304',
        instructor: 'Prof. Johnson',
        type: ClassType.lecture,
      ),
      ClassEvent(
        title: 'Computer Science',
        time: '11:00 AM - 12:30 PM',
        location: 'Lab 105',
        instructor: 'Dr. Smith',
        type: ClassType.lab,
      ),
      ClassEvent(
        title: 'Literature',
        time: '2:00 PM - 3:30 PM',
        location: 'Room 412',
        instructor: 'Dr. Williams',
        type: ClassType.lecture,
      ),
    ];

    _events[DateTime(now.year, now.month, now.day + 1)] = [
      ClassEvent(
        title: 'Physics',
        time: '10:00 AM - 11:30 AM',
        location: 'Room 205',
        instructor: 'Prof. Brown',
        type: ClassType.lecture,
      ),
      ClassEvent(
        title: 'Computer Science Tutorial',
        time: '1:00 PM - 2:30 PM',
        location: 'Lab 107',
        instructor: 'TA Rodriguez',
        type: ClassType.tutorial,
      ),
    ];

    _events[DateTime(now.year, now.month, now.day + 2)] = [
      ClassEvent(
        title: 'Mathematics Problem Session',
        time: '9:30 AM - 11:00 AM',
        location: 'Room 310',
        instructor: 'Prof. Johnson',
        type: ClassType.tutorial,
      ),
      ClassEvent(
        title: 'Literature Discussion',
        time: '2:00 PM - 3:30 PM',
        location: 'Room 415',
        instructor: 'Dr. Williams',
        type: ClassType.discussion,
      ),
    ];
  }

  List<ClassEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final events = _getEventsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.0), // Set the desired height
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Calendar'),
              Tab(text: 'List View'),
            ],
           // indicatorSize: TabBarIndicatorSize.values,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Calendar View
          Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 30)),
                lastDay: DateTime.now().add(const Duration(days: 60)),
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
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildClassItem(events[index]);
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
                      'This Week',
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
                child: ListView(
                  children: [
                    _buildDaySchedule(
                      DateTime.now(),
                      _getEventsForDay(DateTime.now()),
                    ),
                    _buildDaySchedule(
                      DateTime.now().add(const Duration(days: 1)),
                      _getEventsForDay(DateTime.now().add(const Duration(days: 1))),
                    ),
                    _buildDaySchedule(
                      DateTime.now().add(const Duration(days: 2)),
                      _getEventsForDay(DateTime.now().add(const Duration(days: 2))),
                    ),
                    _buildDaySchedule(
                      DateTime.now().add(const Duration(days: 3)),
                      _getEventsForDay(DateTime.now().add(const Duration(days: 3))),
                    ),
                    _buildDaySchedule(
                      DateTime.now().add(const Duration(days: 4)),
                      _getEventsForDay(DateTime.now().add(const Duration(days: 4))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new class functionality
          _showAddClassDialog();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No classes scheduled',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Column(
                children: events.map((event) => _buildClassItem(event)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassItem(ClassEvent event) {
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
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: () {
          // Navigate to class details
          _showClassDetails(event);
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
    }
  }

  void _showClassDetails(ClassEvent event) {
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
          Text(text, style: GoogleFonts.poppins()),
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
    }
  }

  void _showAddClassDialog() {
    // This would open a dialog to add a new class
    // For now, just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Class',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This feature would allow you to add a new class to your schedule.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ClassEvent {
  final String title;
  final String time;
  final String location;
  final String instructor;
  final ClassType type;

  ClassEvent({
    required this.title,
    required this.time,
    required this.location,
    required this.instructor,
    required this.type,
  });
}

enum ClassType {
  lecture,
  lab,
  tutorial,
  discussion,
}