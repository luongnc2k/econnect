class LearningLocation {
  final String id;
  final String name;
  final String address;
  final String? notes;
  final bool isActive;

  const LearningLocation({
    required this.id,
    required this.name,
    required this.address,
    this.notes,
    required this.isActive,
  });

  factory LearningLocation.fromMap(Map<String, dynamic> map) {
    return LearningLocation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      notes: map['notes']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
