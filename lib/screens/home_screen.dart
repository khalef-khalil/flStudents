import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'students_list_screen.dart';
import 'login_screen.dart';
import '../services/database_helper.dart';
import '../models/student.dart';
import '../models/grade.dart';

class StudentAverage {
  final Student student;
  final double average;

  StudentAverage(this.student, this.average);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  int _totalStudents = 0;
  double _classAverage = 0.0;
  Map<String, double> _subjectAverages = {};
  List<Student> _topStudents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('🔄 Starting _loadData()');
    setState(() => _isLoading = true);

    try {
      print('📚 Fetching all students...');
      final students = await _dbHelper.getAllStudents();
      print('👥 Total students found: ${students.length}');
      
      if (students.isEmpty) {
        print('⚠️ No students found in database');
        setState(() {
          _totalStudents = 0;
          _classAverage = 0;
          _subjectAverages = {};
          _topStudents = [];
          _isLoading = false;
        });
        return;
      }

      _totalStudents = students.length;

      double totalAverage = 0;
      int studentCount = 0;
      final subjectGrades = <String, List<double>>{};
      final List<StudentAverage> studentAverages = [];

      print('📊 Starting to calculate averages...');
      // Calculate averages
      for (final student in students) {
        print('\n👤 Processing student: ${student.firstName} ${student.lastName} (ID: ${student.id})');
        if (student.id != null) {
          try {
            print('📝 Fetching grades for student ID: ${student.id}');
            final grades = await _dbHelper.getStudentGrades(student.id!);
            print('📋 Found ${grades.length} grades for student');
            
            if (grades.isNotEmpty) {
              // Normalize grades to 20-point scale
              double normalizedSum = 0;
              for (final grade in grades) {
                double normalizedGrade = grade.value;
                // If grade is on a 100-point scale, convert to 20-point scale
                if (grade.value > 20) {
                  normalizedGrade = (grade.value * 20) / 100;
                }
                normalizedSum += normalizedGrade;
                print('📊 Original grade: ${grade.value}, Normalized grade: $normalizedGrade for ${grade.subject}');
              }
              
              final studentAverage = normalizedSum / grades.length;
              print('📈 Student average (normalized): $studentAverage');
              totalAverage += studentAverage;
              studentCount++;
              studentAverages.add(StudentAverage(student, studentAverage));

              // Group grades by subject with normalized values
              print('📚 Grouping grades by subject');
              for (final grade in grades) {
                double normalizedGrade = grade.value;
                if (grade.value > 20) {
                  normalizedGrade = (grade.value * 20) / 100;
                }
                print('📖 Subject: ${grade.subject}, Original Grade: ${grade.value}, Normalized Grade: $normalizedGrade');
                subjectGrades.putIfAbsent(grade.subject, () => []).add(normalizedGrade);
              }
            } else {
              print('⚠️ No grades found for this student');
            }
          } catch (e) {
            print('❌ Error processing student ${student.id}: $e');
          }
        } else {
          print('⚠️ Student has no ID');
        }
      }

      print('\n📊 Calculating subject averages...');
      final Map<String, double> subjectAverages;
      if (subjectGrades.isEmpty) {
        print('⚠️ No grades found for any subject');
        subjectAverages = {};
      } else {
        subjectAverages = subjectGrades.map((subject, grades) {
          final average = grades.reduce((a, b) => a + b) / grades.length;
          print('📚 $subject average (normalized): $average');
          return MapEntry(subject, average);
        });
      }

      print('\n🏆 Calculating top students...');
      studentAverages.sort((a, b) => b.average.compareTo(a.average));
      final topStudents = studentAverages.take(3).map((e) => e.student).toList();
      
      print('🏆 Top 3 students:');
      for (var i = 0; i < topStudents.length; i++) {
        final student = topStudents[i];
        final average = studentAverages[i].average;
        print('${i + 1}. ${student.firstName} ${student.lastName} (${average.toStringAsFixed(2)}/20)');
      }

      print('\n💾 Updating state with calculated data...');
      setState(() {
        _classAverage = studentCount > 0 ? totalAverage / studentCount : 0;
        _subjectAverages = subjectAverages;
        _topStudents = topStudents;
        _isLoading = false;
      });
      print('✅ Data loading completed successfully');
      print('📊 Class average (normalized): $_classAverage/20');
      print('📚 Subject averages (normalized): $_subjectAverages');

    } catch (e, stackTrace) {
      print('❌ Error in _loadData: $e');
      print('📜 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du chargement des données'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      setState(() {
        _isLoading = false;
        _totalStudents = 0;
        _classAverage = 0;
        _subjectAverages = {};
        _topStudents = [];
      });
    }
  }

  Widget _buildQuickStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aperçu général',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.people,
                    value: _totalStudents.toString(),
                    label: 'Étudiants',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.grade,
                    value: _classAverage.toStringAsFixed(2),
                    label: 'Moyenne',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStudentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 3 étudiants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._topStudents.asMap().entries.map((entry) {
              final index = entry.key;
              final student = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: [
                          const Color(0xFFFFD700), // Gold
                          const Color(0xFFC0C0C0), // Silver
                          const Color(0xFFCD7F32), // Bronze
                        ][index].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: [
                              const Color(0xFFFFD700),
                              const Color(0xFFC0C0C0),
                              const Color(0xFFCD7F32),
                            ][index],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${student.firstName} ${student.lastName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_topStudents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Aucun étudiant noté'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickStatsCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Gestion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNavigationCard(
                      title: 'Liste des étudiants',
                      subtitle: 'Gérer les étudiants',
                      icon: Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentsListScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildNavigationCard(
                      title: 'Notes',
                      subtitle: 'Gérer les notes des étudiants',
                      icon: Icons.grade,
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GradesScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildNavigationCard(
                      title: 'Présences',
                      subtitle: 'Gérer les présences',
                      icon: Icons.calendar_today,
                      color: Theme.of(context).colorScheme.tertiary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildTopStudentsCard(),
                  ],
                ),
              ),
            ),
    );
  }
}
