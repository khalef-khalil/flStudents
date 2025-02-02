import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

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
  bool _isLoading = true;
  Map<String, double> _attendanceStats = {
    'present': 0,
    'absent': 0,
  };
  List<double> _weeklyAttendance = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load students
      final students = await _dbHelper.getAllStudents();
      
      // Load attendance for selected date
      final attendanceMap = <int, bool>{};
      int presentCount = 0;
      
      for (final student in students) {
        if (student.id != null) {
          final attendance = await _dbHelper.getStudentAttendance(student.id!);
          final isPresent = attendance.any((a) => 
            DateFormat('yyyy-MM-dd').format(DateTime.parse(a.date)) == 
            DateFormat('yyyy-MM-dd').format(_selectedDate) && 
            a.status == 'present'
          );
          attendanceMap[student.id!] = isPresent;
          if (isPresent) presentCount++;
        }
      }

      // Calculate weekly attendance
      final weeklyAttendance = List.filled(7, 0.0);
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        int dayPresentCount = 0;
        for (final student in students) {
          if (student.id != null) {
            final attendance = await _dbHelper.getStudentAttendance(student.id!);
            final isPresent = attendance.any((a) => 
              DateFormat('yyyy-MM-dd').format(DateTime.parse(a.date)) == 
              DateFormat('yyyy-MM-dd').format(date) && 
              a.status == 'present'
            );
            if (isPresent) dayPresentCount++;
          }
        }
        weeklyAttendance[6 - i] = students.isNotEmpty 
          ? (dayPresentCount / students.length) * 100 
          : 0;
      }

      setState(() {
        _students = students;
        _attendanceMap = attendanceMap;
        _attendanceStats = {
          'present': presentCount.toDouble(),
          'absent': (students.length - presentCount).toDouble(),
        };
        _weeklyAttendance = weeklyAttendance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
    }
  }

  Future<void> _markAllAttendance(bool present) async {
    setState(() => _isLoading = true);
    try {
      for (final student in _students) {
        if (student.id != null) {
          final attendance = Attendance(
            studentId: student.id!,
            date: _selectedDate.toIso8601String(),
            status: present ? 'present' : 'absent',
          );
          await _dbHelper.insertAttendance(attendance);
        }
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la mise à jour des présences'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAttendance(Student student) async {
    if (student.id == null) return;

    final isPresent = !(_attendanceMap[student.id] ?? false);
    
    try {
      final attendance = Attendance(
        studentId: student.id!,
        date: _selectedDate.toIso8601String(),
        status: isPresent ? 'present' : 'absent',
      );

      await _dbHelper.insertAttendance(attendance);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors de la mise à jour de la présence'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildAttendanceChart() {
    return AspectRatio(
      aspectRatio: 2,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              color: Colors.green.shade400,
              value: _attendanceStats['present'] ?? 0,
              title: '${((_attendanceStats['present'] ?? 0) / _students.length * 100).toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.red.shade400,
              value: _attendanceStats['absent'] ?? 0,
              title: '${((_attendanceStats['absent'] ?? 0) / _students.length * 100).toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    return AspectRatio(
      aspectRatio: 2,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('E').format(date),
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _weeklyAttendance.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
        title: const Text('Gestion des présences'),
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
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _selectedDate,
                        selectedDayPredicate: (day) =>
                          isSameDay(_selectedDate, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = selectedDay;
                          });
                          _loadData();
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Présents',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_attendanceStats['present']?.toInt() ?? 0}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.green.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Absents',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_attendanceStats['absent']?.toInt() ?? 0}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Taux de présence',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildAttendanceChart(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tendance hebdomadaire',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildWeeklyTrendChart(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Liste des étudiants',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _markAllAttendance(true),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Tous présents'),
                              ),
                              TextButton.icon(
                                onPressed: () => _markAllAttendance(false),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('Tous absents'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._students.map((student) {
                      final isPresent = _attendanceMap[student.id] ?? false;
                      return Card(
                        child: ListTile(
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'N° ${student.studentId}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Switch(
                            value: isPresent,
                            onChanged: (bool value) => _toggleAttendance(student),
                            activeColor: Colors.green.shade400,
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
