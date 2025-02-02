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
    print('🗄️ Getting database instance...');
    if (_database != null) {
      print('🗄️ Returning existing database instance');
      return _database!;
    }
    print('🗄️ Initializing new database...');
    _database = await _initDB('student_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    print('🗄️ Initializing database at path: $filePath');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print('🗄️ Full database path: $path');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');
    
    if (newVersion == 4) {
      print('🗑️ Performing complete database reset...');
      // Drop all tables
      await db.execute('DROP TABLE IF EXISTS attendance');
      await db.execute('DROP TABLE IF EXISTS grades');
      await db.execute('DROP TABLE IF EXISTS students');
      
      // Recreate all tables
      await _createDB(db, newVersion);
      return;
    }
    
    if (oldVersion < 2) {
      print('🗑️ Dropping existing tables...');
      // Drop existing tables
      await db.execute('DROP TABLE IF EXISTS attendance');
      await db.execute('DROP TABLE IF EXISTS grades');
      await db.execute('DROP TABLE IF EXISTS students');
      
      print('📝 Recreating all tables...');
      // Recreate all tables
      await _createDB(db, newVersion);
    }
    if (oldVersion < 3) {
      // Add email and phone columns to students table
      await db.execute('ALTER TABLE students ADD COLUMN email TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN phone TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    print('📝 Creating database tables...');
    try {
      // Table des étudiants
      print('👥 Creating students table...');
      await db.execute('''
        CREATE TABLE students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firstName TEXT NOT NULL,
          lastName TEXT NOT NULL,
          studentId TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          email TEXT,
          phone TEXT
        )
      ''');
      print('✅ Students table created successfully');

      // Table des notes
      print('📊 Creating grades table...');
      await db.execute('''
        CREATE TABLE grades (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          studentId INTEGER NOT NULL,
          subject TEXT NOT NULL,
          value REAL NOT NULL,
          date TEXT NOT NULL,
          FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
      print('✅ Grades table created successfully');

      // Table des présences
      print('📅 Creating attendance table...');
      await db.execute('''
        CREATE TABLE attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          studentId INTEGER NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');
      print('✅ Attendance table created successfully');
      print('✅ All tables created successfully');
    } catch (e, stackTrace) {
      print('❌ Error creating database tables: $e');
      print('📜 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Méthodes CRUD pour les étudiants
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<int> updateStudent(Student student) async {
    print('📝 Updating student: ${student.firstName} ${student.lastName}');
    if (student.id == null) {
      throw Exception('Cannot update student without an ID');
    }
    
    final db = await database;
    
    // Check if the new studentId already exists for a different student
    final List<Map<String, dynamic>> existingStudents = await db.query(
      'students',
      where: 'studentId = ? AND id != ?',
      whereArgs: [student.studentId, student.id],
    );
    
    if (existingStudents.isNotEmpty) {
      print('❌ Student ID ${student.studentId} already exists for another student');
      throw Exception('Un étudiant avec ce numéro existe déjà');
    }
    
    print('✅ Updating student with ID: ${student.id}');
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Student>> getAllStudents() async {
    print('📚 DB: Getting all students...');
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    print('📚 DB: Found ${maps.length} students in database');
    return List.generate(maps.length, (i) {
      print('📚 DB: Processing student ${i + 1}: ${maps[i]}');
      return Student.fromMap(maps[i]);
    });
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
    print('📝 DB: Getting grades for student ID: $studentId');
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'grades',
      where: 'studentId = ?',
      whereArgs: [studentId],
    );
    print('📝 DB: Found ${maps.length} grades for student $studentId');
    return List.generate(maps.length, (i) {
      print('📝 DB: Processing grade ${i + 1}: ${maps[i]}');
      return Grade.fromMap(maps[i]);
    });
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

    // Sort students by average
    final sortedIds = studentAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Find the position of the target student
    return sortedIds.indexWhere((entry) => entry.key == studentId) + 1;
  }

  // Method to clear all data from the database
  Future<void> clearAllData() async {
    print('🗑️ Starting database cleanup...');
    final db = await database;
    
    try {
      // Start a transaction to ensure all operations complete or none do
      await db.transaction((txn) async {
        print('🗑️ Deleting attendance records...');
        await txn.delete('attendance');
        
        print('🗑️ Deleting grades records...');
        await txn.delete('grades');
        
        print('🗑️ Deleting student records...');
        await txn.delete('students');
      });
      
      print('✅ All data cleared successfully');
    } catch (e) {
      print('❌ Error clearing database: $e');
      rethrow;
    }
  }

  // Method to reset database connection
  Future<void> resetDatabase() async {
    print('🔄 Resetting database connection...');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Method to completely reset database
  Future<void> resetCompleteDatabase() async {
    print('🗑️ Starting complete database reset...');
    try {
      await clearAllData();
      await resetDatabase();
      print('✅ Database reset complete');
    } catch (e) {
      print('❌ Error resetting database: $e');
      rethrow;
    }
  }
}
