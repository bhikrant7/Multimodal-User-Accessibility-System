class AlertEvent {
  final String message;
  final DateTime timestamp;
  final String category;

  AlertEvent({
    required this.message,
    required this.timestamp,
    required this.category,
  });
}
