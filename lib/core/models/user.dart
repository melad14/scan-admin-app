class PatientUser {
  final String id;
  final String name;
  final String phone;
  final int? age;
  final String? gender;
  final bool isActive;

  PatientUser({
    required this.id,
    required this.name,
    required this.phone,
    this.age,
    this.gender,
    this.isActive = true,
  });

  factory PatientUser.fromJson(Map<String, dynamic> json) {
    return PatientUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      age: json['age'] as int?,
      gender: json['gender'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'isActive': isActive,
    };
  }
}
