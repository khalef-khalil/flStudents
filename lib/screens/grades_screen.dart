import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../services/database_helper.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Student> _students = [];
  Map<int, TextEditingController> _gradeControllers = {};
  String _selectedCourse = 'Mathématiques';

  final List<String> _courses = [
    'Mathématiques',
    'Physique',
    'Français'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var controller in _gradeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final students = await _dbHelper.getAllStudents();
    final newControllers = <int, TextEditingController>{};
    
    for (final student in students) {
      if (student.id != null) {
        final grades = await _dbHelper.getStudentGrades(student.id!);
        final currentGrade = grades.where((g) => 
          g.subject == _selectedCourse
        ).firstOrNull;
        
        newControllers[student.id!] = TextEditingController(
          text: currentGrade?.value.toString() ?? ''
        );
      }
    }

    setState(() {
      _students = students;
      // Dispose old controllers
      for (var controller in _gradeControllers.values) {
        controller.dispose();
      }
      _gradeControllers = newControllers;
    });
  }

  Future<void> _saveGrade(Student student, String value) async {
    if (student.id == null || value.isEmpty) return;

    final gradeValue = double.tryParse(value);
    if (gradeValue == null || gradeValue < 0 || gradeValue > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La note doit être comprise entre 0 et 20'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final grade = Grade(
      studentId: student.id!,
      subject: _selectedCourse,
      value: gradeValue,
      date: DateTime.now().toIso8601String(), // Keep date for database consistency
    );

    await _dbHelper.insertGrade(grade);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des notes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Matière',
                border: OutlineInputBorder(),
              ),
              items: _courses.map((String course) {
                return DropdownMenuItem<String>(
                  value: course,
                  child: Text(course),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCourse = newValue;
                  });
                  _loadData();
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final controller = student.id != null 
                  ? _gradeControllers[student.id] 
                  : TextEditingController();
                
                if (controller == null) return const SizedBox.shrink();
                
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text('${student.firstName} ${student.lastName}'),
                  subtitle: Text(student.studentId),
                  trailing: SizedBox(
                    width: 70,
                    child: TextFormField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '0-20',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onChanged: (value) => _saveGrade(student, value),
                    ),
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
