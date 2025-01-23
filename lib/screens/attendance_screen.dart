import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Student> _students = [];
  DateTime _selectedDate = DateTime.now();
  Map<int, bool> _attendanceMap = {};
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load students
    final students = await _dbHelper.getAllStudents();
    
    // Load attendance for selected date
    final attendanceMap = <int, bool>{};
    for (final student in students) {
      if (student.id != null) {
        final attendance = await _dbHelper.getStudentAttendance(student.id!);
        final isPresent = attendance.any((a) => 
          DateFormat('yyyy-MM-dd').format(DateTime.parse(a.date)) == 
          DateFormat('yyyy-MM-dd').format(_selectedDate) && 
          a.isPresent == 1
        );
        attendanceMap[student.id!] = isPresent;
      }
    }

    setState(() {
      _students = students;
      _attendanceMap = attendanceMap;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
    }
  }

  Future<void> _toggleAttendance(Student student) async {
    if (student.id == null) return;

    final isPresent = !(_attendanceMap[student.id] ?? false);
    
    final attendance = Attendance(
      studentId: student.id!,
      date: _selectedDate.toIso8601String(),
      isPresent: isPresent ? 1 : 0,
    );

    await _dbHelper.insertAttendance(attendance);
    
    setState(() {
      _attendanceMap[student.id!] = isPresent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des présences'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${_dateFormat.format(_selectedDate)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Changer la date'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final isPresent = _attendanceMap[student.id] ?? false;
                
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text('${student.firstName} ${student.lastName}'),
                  subtitle: Text(student.studentId),
                  trailing: Checkbox(
                    value: isPresent,
                    onChanged: (bool? value) {
                      _toggleAttendance(student);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
