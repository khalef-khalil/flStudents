class Grade {
  final int? id;
  final int studentId;
  final String subject;
  final double value;
  final String date;

  Grade({
    this.id,
    required this.studentId,
    required this.subject,
    required this.value,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'studentId': studentId,
      'subject': subject,
      'value': value,
      'date': date,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Grade.fromMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      subject: map['subject'] as String,
      value: (map['value'] as num).toDouble(),
      date: map['date'] as String,
    );
  }
}
