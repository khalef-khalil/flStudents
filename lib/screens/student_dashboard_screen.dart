import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../services/database_helper.dart';
import 'login_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Student student;

  const StudentDashboardScreen({super.key, required this.student});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Grade> _grades = [];
  int _rank = 0;
  double _overallAverage = 0.0;
  Map<String, double> _subjectAverages = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.student.id == null) return;

    final grades = await _dbHelper.getStudentGrades(widget.student.id!);
    final rank = await _dbHelper.getStudentRank(widget.student.id!);
    
    // Calculate overall average
    final overallAverage = grades.isEmpty 
      ? 0.0 
      : grades.map((g) => g.value).reduce((a, b) => a + b) / grades.length;

    // Calculate subject averages
    final subjectGrades = <String, List<double>>{};
    for (final grade in grades) {
      subjectGrades.putIfAbsent(grade.subject, () => []).add(grade.value);
    }
    
    final subjectAverages = subjectGrades.map((subject, grades) {
      final average = grades.reduce((a, b) => a + b) / grades.length;
      return MapEntry(subject, average);
    });

    setState(() {
      _grades = grades;
      _rank = rank;
      _overallAverage = overallAverage;
      _subjectAverages = subjectAverages;
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.student.firstName} ${widget.student.lastName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Numéro étudiant: ${widget.student.studentId}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Classement: ${_rank == 0 ? "N/A" : "${_rank}e"}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Moyenne générale: ${_overallAverage.toStringAsFixed(2)}/20',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notes par matière',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._subjectAverages.entries.map((entry) => Card(
              child: ListTile(
                title: Text(entry.key),
                trailing: Text(
                  '${entry.value.toStringAsFixed(2)}/20',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )),
            if (_subjectAverages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aucune note enregistrée'),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 