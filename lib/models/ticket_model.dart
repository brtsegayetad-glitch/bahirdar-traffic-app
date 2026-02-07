class TrafficTicket {
  final String id;
  final String plate;
  final String violation;
  final double amount;
  final String status; // 'UNPAID' or 'PAID'
  final DateTime createdAt;
  final String officerId;

  TrafficTicket({
    required this.id,
    required this.plate,
    required this.violation,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.officerId,
  });

  // Convert to a Map to send to Firebase
  Map<String, dynamic> toMap() {
    return {
      'plate': plate,
      'violation': violation,
      'amount': amount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'officerId': officerId,
    };
  }
}
