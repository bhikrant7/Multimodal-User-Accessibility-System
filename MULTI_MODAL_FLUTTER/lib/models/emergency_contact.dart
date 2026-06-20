class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isPrimary;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.isPrimary = false,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
