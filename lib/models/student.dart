class Student {
  final int? id;
  final String firstName;
  final String lastName;
  final String studentId;
  final String password;
  final String? email;
  final String? phone;

  Student({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.studentId,
    required this.password,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'firstName': firstName,
      'lastName': lastName,
      'studentId': studentId,
      'password': password,
      'email': email,
      'phone': phone,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      studentId: map['studentId'] as String,
      password: map['password'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
    );
  }
}
