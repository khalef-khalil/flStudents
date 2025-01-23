class Attendance {
  final int? id;
  final int studentId;
  final String date;
  final int isPresent;

  Attendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.isPresent,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'studentId': studentId,
      'date': date,
      'isPresent': isPresent,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      date: map['date'] as String,
      isPresent: map['isPresent'] as int,
    );
  }
}
