import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.student.id == null) return;

    setState(() => _isLoading = true);

    try {
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

      if (mounted) {
        setState(() {
          _grades = grades;
          _rank = rank;
          _overallAverage = overallAverage;
          _subjectAverages = subjectAverages;
          _isLoading = false;
        });
      }
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

  List<PieChartSectionData> _getSections() {
    final List<Color> colors = [
      const Color(0xFF2563EB), // Primary blue
      const Color(0xFF0EA5E9), // Secondary blue
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
    ];

    return _subjectAverages.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final subject = entry.value.key;
      final average = entry.value.value;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: average,
        title: '${average.toStringAsFixed(1)}',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildGradeChart() {
    if (_subjectAverages.isEmpty) {
      return const Center(
        child: Text('Aucune note enregistrée'),
      );
    }

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: _getSections(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          startDegreeOffset: -90,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final List<Color> colors = [
      const Color(0xFF2563EB),
      const Color(0xFF0EA5E9),
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: _subjectAverages.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final subject = entry.value.key;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(subject),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Mon tableau de bord'),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    '${widget.student.firstName[0]}${widget.student.lastName[0]}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.student.firstName} ${widget.student.lastName}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'N° ${widget.student.studentId}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    _overallAverage.toStringAsFixed(2),
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const Text('Moyenne générale'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    _rank == 0 ? 'N/A' : '$_rank${_rank == 1 ? 'er' : 'ème'}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  const Text('Classement'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Répartition des notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildGradeChart(),
                            const SizedBox(height: 16),
                            _buildLegend(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Détail des moyennes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._subjectAverages.entries.map((entry) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            entry.key[0],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(entry.key),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${entry.value.toStringAsFixed(2)}/20',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            ),
    );
  }
} 