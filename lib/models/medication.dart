class Medication {
  int? id;
  final String name;
  final String description;
  final String photoPath;
  final String audioPath;
  final List<String> alarmTimes; // Store as comma-separated time strings HH:mm
  final bool isActive;

  Medication({
    this.id,
    required this.name,
    required this.description,
    required this.photoPath,
    required this.audioPath,
    required this.alarmTimes,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photoPath': photoPath,
      'audioPath': audioPath,
      'alarmTimes': alarmTimes.join(','),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      photoPath: map['photoPath'],
      audioPath: map['audioPath'],
      alarmTimes: map['alarmTimes'].split(','),
      isActive: map['isActive'] == 1,
    );
  }
}
