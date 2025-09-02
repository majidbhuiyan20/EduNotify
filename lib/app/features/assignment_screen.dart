import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Assignment> _assignments = [];
  final List<Assignment> _completedAssignments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAssignments();
  }

  void _loadAssignments() {
    // Sample data
    setState(() {
      _assignments.addAll([
        Assignment(
          id: '1',
          title: 'Mathematics Problem Set 5',
          subject: 'Mathematics',
          dueDate: DateTime.now().add(const Duration(days: 2)),
          description: 'Complete chapters 5-7 problems. Show all your work and calculations.',
          status: AssignmentStatus.pending,
          priority: Priority.high,
        ),
        Assignment(
          id: '2',
          title: 'Literature Essay: Modern Poetry',
          subject: 'Literature',
          dueDate: DateTime.now().add(const Duration(days: 5)),
          description: 'Write a 1500-word essay analyzing the themes in modern poetry.',
          status: AssignmentStatus.pending,
          priority: Priority.medium,
        ),
        Assignment(
          id: '3',
          title: 'Computer Science Project',
          subject: 'Computer Science',
          dueDate: DateTime.now().add(const Duration(hours: 12)),
          description: 'Complete the Flutter UI implementation for the final project.',
          status: AssignmentStatus.pending,
          priority: Priority.high,
        ),
        Assignment(
          id: '4',
          title: 'History Research Paper',
          subject: 'History',
          dueDate: DateTime.now().add(const Duration(days: 7)),
          description: 'Research paper on World War II impacts (2500 words minimum).',
          status: AssignmentStatus.pending,
          priority: Priority.medium,
        ),
      ]);

      _completedAssignments.addAll([
        Assignment(
          id: '5',
          title: 'Physics Lab Report',
          subject: 'Physics',
          dueDate: DateTime.now().subtract(const Duration(days: 3)),
          description: 'Lab report on Newton\'s Laws of Motion experiment.',
          status: AssignmentStatus.completed,
          priority: Priority.low,
          completedDate: DateTime.now().subtract(const Duration(days: 4)),
        ),
        Assignment(
          id: '6',
          title: 'Biology Worksheet',
          subject: 'Biology',
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          description: 'Complete the cell biology worksheet questions.',
          status: AssignmentStatus.completed,
          priority: Priority.low,
          completedDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
    });
  }

  void _markAsCompleted(Assignment assignment) {
    setState(() {
      _assignments.remove(assignment);
      _completedAssignments.add(assignment.copyWith(
        status: AssignmentStatus.completed,
        completedDate: DateTime.now(),
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${assignment.title} marked as completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _markAsPending(Assignment assignment) {
    setState(() {
      _completedAssignments.remove(assignment);
      _assignments.add(assignment.copyWith(
        status: AssignmentStatus.pending,
        completedDate: null,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${assignment.title} moved to pending.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAssignmentDetails(Assignment assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssignmentDetailsBottomSheet(
        assignment: assignment,
        onStatusChanged: () {
          if (assignment.status == AssignmentStatus.pending) {
            _markAsCompleted(assignment);
          } else {
            _markAsPending(assignment);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAssignmentDialog(
        onAssignmentAdded: (newAssignment) {
          setState(() {
            _assignments.add(newAssignment);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assignments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                'Pending (${_assignments.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
            Tab(
              child: Text(
                'Completed (${_completedAssignments.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending Assignments Tab
          _assignments.isEmpty
              ? _buildEmptyState('No pending assignments', Icons.assignment_turned_in)
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _assignments.length,
            itemBuilder: (context, index) {
              return AssignmentCard(
                assignment: _assignments[index],
                onTap: () => _showAssignmentDetails(_assignments[index]),
                onComplete: () => _markAsCompleted(_assignments[index]),
              );
            },
          ),

          // Completed Assignments Tab
          _completedAssignments.isEmpty
              ? _buildEmptyState('No completed assignments', Icons.assignment_turned_in)
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _completedAssignments.length,
            itemBuilder: (context, index) {
              return CompletedAssignmentCard(
                assignment: _completedAssignments[index],
                onTap: () => _showAssignmentDetails(_completedAssignments[index]),
                onReopen: () => _markAsPending(_completedAssignments[index]),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssignmentDialog,
        icon: const Icon(Icons.add),
        label: Text('Add Assignment', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onTap,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final daysRemaining = assignment.dueDate.difference(DateTime.now()).inDays;
    final hoursRemaining = assignment.dueDate.difference(DateTime.now()).inHours;
    final isDueSoon = daysRemaining <= 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority Indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(assignment.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subject Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      assignment.subject,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getSubjectColor(assignment.subject),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Due Date
                  Text(
                    DateFormat('MMM d').format(assignment.dueDate),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                assignment.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                assignment.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Progress and Action Row
              Row(
                children: [
                  // Time Remaining
                  Icon(Icons.access_time, size: 16, color: isDueSoon ? Colors.red : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    isDueSoon
                        ? 'Due in $hoursRemaining hours'
                        : 'Due in $daysRemaining days',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDueSoon ? Colors.red : Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  // Complete Button
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Complete',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
    };
    return subjectColors[subject] ?? Colors.grey;
  }
}

class CompletedAssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;
  final VoidCallback onReopen;

  const CompletedAssignmentCard({
    super.key,
    required this.assignment,
    required this.onTap,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.grey[50],
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Completed Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Completion Date
                  Text(
                    DateFormat('MMM d').format(assignment.completedDate!),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                assignment.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                assignment.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Action Row
              Row(
                children: [
                  // Subject
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      assignment.subject,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getSubjectColor(assignment.subject),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Reopen Button
                  OutlinedButton(
                    onPressed: onReopen,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Reopen',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
    };
    return subjectColors[subject] ?? Colors.grey;
  }
}

class AssignmentDetailsBottomSheet extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onStatusChanged;

  const AssignmentDetailsBottomSheet({
    super.key,
    required this.assignment,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            assignment.title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Subject and Due Date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  assignment.subject,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getSubjectColor(assignment.subject),
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, yyyy').format(assignment.dueDate),
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            'Description',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assignment.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Priority
          Text(
            'Priority',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getPriorityColor(assignment.priority),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getPriorityText(assignment.priority),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStatusChanged,
              style: ElevatedButton.styleFrom(
                backgroundColor: assignment.status == AssignmentStatus.pending
                    ? Colors.blue
                    : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                assignment.status == AssignmentStatus.pending
                    ? 'Mark as Completed'
                    : 'Mark as Pending',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
    };
    return subjectColors[subject] ?? Colors.grey;
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.high:
        return 'High Priority';
      case Priority.medium:
        return 'Medium Priority';
      case Priority.low:
        return 'Low Priority';
    }
  }
}

class AddAssignmentDialog extends StatefulWidget {
  final Function(Assignment) onAssignmentAdded;

  const AddAssignmentDialog({super.key, required this.onAssignmentAdded});

  @override
  State<AddAssignmentDialog> createState() => _AddAssignmentDialogState();
}

class _AddAssignmentDialogState extends State<AddAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  Priority _priority = Priority.medium;

  final List<String> _subjects = [
    'Mathematics',
    'Literature',
    'Computer Science',
    'History',
    'Physics',
    'Biology',
    'Chemistry',
    'Geography',
  ];

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newAssignment = Assignment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        subject: _subjectController.text,
        dueDate: _dueDate,
        description: _descriptionController.text,
        status: AssignmentStatus.pending,
        priority: _priority,
      );

      widget.onAssignmentAdded(newAssignment);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Assignment',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Assignment Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Subject Dropdown
              DropdownButtonFormField<String>(
                value: _subjectController.text.isEmpty ? null : _subjectController.text,
                items: _subjects.map((String subject) {
                  return DropdownMenuItem<String>(
                    value: subject,
                    child: Text(subject),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _subjectController.text = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Due Date Picker
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM d, yyyy').format(_dueDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Priority Selector
              Text(
                'Priority',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip(Priority.low, 'Low'),
                  const SizedBox(width: 8),
                  _buildPriorityChip(Priority.medium, 'Medium'),
                  const SizedBox(width: 8),
                  _buildPriorityChip(Priority.high, 'High'),
                ],
              ),
              const SizedBox(height: 16),
              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add Assignment',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(Priority priority, String label) {
    final isSelected = _priority == priority;
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _priority = priority;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: _getPriorityColor(priority),
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }
}

// Data Models
enum AssignmentStatus { pending, completed }
enum Priority { low, medium, high }

class Assignment {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String description;
  final AssignmentStatus status;
  final Priority priority;
  final DateTime? completedDate;

  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.description,
    required this.status,
    required this.priority,
    this.completedDate,
  });

  Assignment copyWith({
    String? id,
    String? title,
    String? subject,
    DateTime? dueDate,
    String? description,
    AssignmentStatus? status,
    Priority? priority,
    DateTime? completedDate,
  }) {
    return Assignment(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      completedDate: completedDate ?? this.completedDate,
    );
  }
}