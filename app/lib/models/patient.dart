class Patient {
  final int? id;
  final String name;
  final int? age;
  final String? sex;
  final DateTime createdAt;

  Patient({
    this.id,
    required this.name,
    this.age,
    this.sex,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'sex': sex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Patient.fromMap(Map<String, dynamic> map) => Patient(
        id: map['id'] as int?,
        name: map['name'] as String,
        age: map['age'] as int?,
        sex: map['sex'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Patient copyWith({int? id}) => Patient(
        id: id ?? this.id,
        name: name,
        age: age,
        sex: sex,
        createdAt: createdAt,
      );
}
