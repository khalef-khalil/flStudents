import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
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
  bool _isLoading = true;
  double _courseAverage = 0.0;
  Map<String, int> _gradeDistribution = {};

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
    setState(() => _isLoading = true);

    try {
      final students = await _dbHelper.getAllStudents();
      final newControllers = <int, TextEditingController>{};
      double totalGrade = 0;
      int gradeCount = 0;
      final distribution = <String, int>{
        '0-5': 0,
        '5-10': 0,
        '10-15': 0,
        '15-20': 0,
      };
      
      for (final student in students) {
        if (student.id != null) {
          final grades = await _dbHelper.getStudentGrades(student.id!);
          final currentGrade = grades.where((g) => 
            g.subject == _selectedCourse
          ).firstOrNull;
          
          if (currentGrade != null) {
            totalGrade += currentGrade.value;
            gradeCount++;

            // Update grade distribution
            if (currentGrade.value <= 5) distribution['0-5'] = (distribution['0-5'] ?? 0) + 1;
            else if (currentGrade.value <= 10) distribution['5-10'] = (distribution['5-10'] ?? 0) + 1;
            else if (currentGrade.value <= 15) distribution['10-15'] = (distribution['10-15'] ?? 0) + 1;
            else distribution['15-20'] = (distribution['15-20'] ?? 0) + 1;
          }
          
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
        _courseAverage = gradeCount > 0 ? totalGrade / gradeCount : 0;
        _gradeDistribution = distribution;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du chargement des données'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveGrade(Student student, String value) async {
    if (student.id == null || value.isEmpty) return;

    final gradeValue = double.tryParse(value);
    if (gradeValue == null || gradeValue < 0 || gradeValue > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La note doit être comprise entre 0 et 20'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      final grade = Grade(
        studentId: student.id!,
        subject: _selectedCourse,
        value: gradeValue,
        date: DateTime.now().toIso8601String(),
      );

      await _dbHelper.insertGrade(grade);
      _loadData(); // Refresh data to update statistics
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de l\'enregistrement de la note'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildGradeDistributionChart() {
    return AspectRatio(
      aspectRatio: 2,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _gradeDistribution.values.fold(0, (p, c) => p > c ? p : c).toDouble(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = ['0-5', '5-10', '10-15', '15-20'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == value.roundToDouble()) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: _gradeDistribution['0-5']?.toDouble() ?? 0,
                  color: Colors.red.shade300,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: _gradeDistribution['5-10']?.toDouble() ?? 0,
                  color: Colors.orange.shade300,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 2,
              barRods: [
                BarChartRodData(
                  toY: _gradeDistribution['10-15']?.toDouble() ?? 0,
                  color: Colors.blue.shade300,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
            BarChartGroupData(
              x: 3,
              barRods: [
                BarChartRodData(
                  toY: _gradeDistribution['15-20']?.toDouble() ?? 0,
                  color: Colors.green.shade300,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
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
        title: const Text('Gestion des notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
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
                            const SizedBox(height: 16),
                            Text(
                              'Moyenne de la classe: ${_courseAverage.toStringAsFixed(2)}/20',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Distribution des notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildGradeDistributionChart(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Notes des étudiants',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._students.map((student) {
                      final controller = student.id != null 
                        ? _gradeControllers[student.id] 
                        : TextEditingController();
                      
                      if (controller == null) return const SizedBox.shrink();
                      
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Text(
                                  '${student.firstName[0]}${student.lastName[0]}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student.firstName} ${student.lastName}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'N° ${student.studentId}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: controller,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0-20',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (value) => _saveGrade(student, value),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
