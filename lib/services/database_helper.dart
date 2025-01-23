import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/grade.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('student_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop existing tables
      await db.execute('DROP TABLE IF EXISTS attendance');
      await db.execute('DROP TABLE IF EXISTS grades');
      await db.execute('DROP TABLE IF EXISTS students');
      
      // Recreate all tables
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Table des étudiants
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        studentId TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // Table des notes
    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        subject TEXT NOT NULL,
        value REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (studentId) REFERENCES students (id)
      )
    ''');

    // Table des présences
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        FOREIGN KEY (studentId) REFERENCES students (id)
      )
    ''');
  }

  // Méthodes CRUD pour les étudiants
  Future<int> insertStudent(Student student) async {
    final db = await database;
    
    // Check if studentId already exists
    final List<Map<String, dynamic>> existingStudents = await db.query(
      'students',
      where: 'studentId = ?',
      whereArgs: [student.studentId],
    );
    
    if (existingStudents.isNotEmpty) {
      throw Exception('Un étudiant avec ce numéro existe déjà');
    }
    
    final map = student.toMap();
    map.remove('id'); // Remove ID for insert
    return await db.insert('students', map);
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    if (student.id == null) {
      throw Exception('Cannot update student without an ID');
    }
    
    // First check if the new studentId already exists for a different student
    final List<Map<String, dynamic>> existingStudents = await db.query(
      'students',
      where: 'studentId = ? AND id != ?',
      whereArgs: [student.studentId, student.id],
    );
    
    if (existingStudents.isNotEmpty) {
      throw Exception('Un étudiant avec ce numéro existe déjà');
    }
    
    final map = student.toMap();
    map.remove('id'); // Remove ID from update data
    
    return await db.update(
      'students',
      map,
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // Méthodes pour les notes
  Future<int> insertGrade(Grade grade) async {
    final db = await database;
    
    // Check if a grade already exists for this student and subject
    final List<Map<String, dynamic>> existingGrades = await db.query(
      'grades',
      where: 'studentId = ? AND subject = ?',
      whereArgs: [grade.studentId, grade.subject],
    );
    
    if (existingGrades.isNotEmpty) {
      // Update existing grade
      return await db.update(
        'grades',
        grade.toMap(),
        where: 'id = ?',
        whereArgs: [existingGrades.first['id']],
      );
    } else {
      // Insert new grade
      return await db.insert('grades', grade.toMap());
    }
  }

  Future<List<Grade>> getStudentGrades(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'grades',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
  }

  // Méthodes pour les présences
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert('attendance', attendance.toMap());
  }

  Future<List<Attendance>> getStudentAttendance(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  // Authentication methods
  Future<bool> authenticateProfessor(String username, String password) async {
    return username == 'prof' && password == 'pass';
  }

  Future<Student?> authenticateStudent(String studentId, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'studentId = ? AND password = ?',
      whereArgs: [studentId, password],
    );
    
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  // Get student rank
  Future<int> getStudentRank(int studentId) async {
    final db = await database;
    final allStudents = await getAllStudents();
    final studentAverages = <int, double>{};

    for (final student in allStudents) {
      if (student.id != null) {
        final grades = await getStudentGrades(student.id!);
        if (grades.isNotEmpty) {
          final average = grades.map((g) => g.value).reduce((a, b) => a + b) / grades.length;
          studentAverages[student.id!] = average;
        }
      }
    }

    final sortedStudents = studentAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final rank = sortedStudents.indexWhere((entry) => entry.key == studentId) + 1;
    return rank > 0 ? rank : sortedStudents.length + 1;
  }
}
