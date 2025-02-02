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
  List<Student> _filteredStudents = [];
  Map<int, List<Grade>> _grades = {};
  double _classAverage = 0.0;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredStudents = _students.where((student) {
        final fullName = '${student.firstName} ${student.lastName}'.toLowerCase();
        final studentId = student.studentId.toLowerCase();
        return fullName.contains(_searchQuery) || studentId.contains(_searchQuery);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
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
        _filteredStudents = students;
        _grades = grades;
        _classAverage = studentCount > 0 ? totalAverage / studentCount : 0.0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(Student student) async {
    if (student.id == null) return;
    
    try {
      await _dbHelper.deleteStudent(student.id!);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Étudiant supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateStudentAverage(List<Grade> grades) {
    if (grades.isEmpty) return 0.0;
    double normalizedSum = 0.0;
    for (final grade in grades) {
      double normalizedGrade = grade.value;
      if (grade.value > 20) {
        normalizedGrade = (grade.value * 20) / 100;
      }
      normalizedSum += normalizedGrade;
    }
    return normalizedSum / grades.length;
  }

  Map<String, double> _calculateStudentSubjectAverages(List<Grade> grades) {
    final subjectGrades = <String, List<double>>{};
    
    for (final grade in grades) {
      double normalizedGrade = grade.value;
      if (grade.value > 20) {
        normalizedGrade = (grade.value * 20) / 100;
      }
      subjectGrades.putIfAbsent(grade.subject, () => []).add(normalizedGrade);
    }
    
    return subjectGrades.map((subject, grades) {
      final average = grades.reduce((a, b) => a + b) / grades.length;
      return MapEntry(subject, average);
    });
  }

  Color _getGradeColor(double grade) {
    if (grade >= 16) return Colors.green;
    if (grade >= 14) return Colors.lightGreen;
    if (grade >= 12) return Colors.orange;
    if (grade >= 10) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Étudiants'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Moyenne de la classe: ${_classAverage.toStringAsFixed(2)}/20',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterStudents,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un étudiant...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterStudents('');
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        : _filteredStudents.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isEmpty
                  ? 'Aucun étudiant enregistré'
                  : 'Aucun résultat trouvé',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _filteredStudents.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                final grades = _grades[student.id] ?? [];
                final average = _calculateStudentAverage(grades);
                final subjectAverages = _calculateStudentSubjectAverages(grades);
                
                return Dismissible(
                  key: Key(student.id.toString()),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmer la suppression'),
                        content: Text('Voulez-vous vraiment supprimer ${student.firstName} ${student.lastName} ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (result == true) {
                      await _deleteStudent(student);
                    }
                    return result;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          '${student.firstName[0]}${student.lastName[0]}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${student.firstName} ${student.lastName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Row(
                        children: [
                          Text('N° ${student.studentId}'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getGradeColor(average),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${average.toStringAsFixed(2)}/20',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditStudentScreen(student: student),
                                ),
                              );
                              if (result == true && mounted) {
                                _loadData();
                              }
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Text(
                                'Notes par matière:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              if (subjectAverages.isEmpty)
                                const Text(
                                  'Aucune note enregistrée',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                )
                              else
                                ...subjectAverages.entries.map((e) => 
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(e.key),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: LinearProgressIndicator(
                                            value: e.value / 20,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              _getGradeColor(e.value),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${e.value.toStringAsFixed(2)}/20',
                                          style: TextStyle(
                                            color: _getGradeColor(e.value),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditStudentScreen(),
            ),
          );
          if (result == true && mounted) {
            _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
