enum DangerPriority { low, medium, high }

class DangerAlert {
  final String message;
  final DangerPriority priority;
  final DateTime timestamp;
  final String sound;
  final String? details;

  DangerAlert({
    required this.message,
    required this.priority,
    required this.timestamp,
    required this.sound,
    this.details,
  });
}
