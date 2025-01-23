import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../services/database_helper.dart';
import 'add_edit_student_screen.dart';
import 'login_screen.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Student> _students = [];
  Map<int, List<Grade>> _grades = {};
  double _classAverage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final students = await _dbHelper.getAllStudents();
    final grades = <int, List<Grade>>{};
    double totalAverage = 0.0;
    int studentCount = 0;

    for (final student in students) {
      if (student.id != null) {
        final studentGrades = await _dbHelper.getStudentGrades(student.id!);
        grades[student.id!] = studentGrades;
        
        if (studentGrades.isNotEmpty) {
          totalAverage += _calculateStudentAverage(studentGrades);
          studentCount++;
        }
      }
    }

    setState(() {
      _students = students;
      _grades = grades;
      _classAverage = studentCount > 0 ? totalAverage / studentCount : 0.0;
    });
  }

  double _calculateStudentAverage(List<Grade> grades) {
    if (grades.isEmpty) return 0.0;
    final total = grades.fold(0.0, (sum, grade) => sum + grade.value);
    return total / grades.length;
  }

  Map<String, double> _calculateStudentSubjectAverages(List<Grade> grades) {
    final subjectGrades = <String, List<double>>{};
    
    for (final grade in grades) {
      subjectGrades.putIfAbsent(grade.subject, () => []).add(grade.value);
    }
    
    return subjectGrades.map((subject, grades) {
      final average = grades.reduce((a, b) => a + b) / grades.length;
      return MapEntry(subject, average);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Étudiants'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Moyenne de la classe: ${_classAverage.toStringAsFixed(2)}/20',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          final grades = _grades[student.id] ?? [];
          final average = _calculateStudentAverage(grades);
          final subjectAverages = _calculateStudentSubjectAverages(grades);
          
          return ExpansionTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text('${student.firstName} ${student.lastName}'),
            subtitle: Text('Moyenne: ${average.toStringAsFixed(2)}/20'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditStudentScreen(student: student),
                  ),
                );
                _loadData();
              },
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Numéro étudiant: ${student.studentId}'),
                    const Divider(),
                    const Text('Moyennes par matière:'),
                    ...subjectAverages.entries.map((e) => 
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                        child: Text('${e.key}: ${e.value.toStringAsFixed(2)}/20'),
                      ),
                    ),
                    if (subjectAverages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0, top: 4.0),
                        child: Text('Aucune note enregistrée'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditStudentScreen(),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
