class SoundEvent {
  final String id;
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String type; // 'emergency', 'warning', 'info'

  SoundEvent({
    required this.id,
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.type,
  });

  bool get isEmergency => type == 'emergency';
}

class Contact {
  final String name;
  final String phone;
  final String relation;
  final String? fcmToken; // Optional FCM token for push notifications

  Contact({
    required this.name,
    required this.phone,
    required this.relation,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relation': relation,
        if (fcmToken != null) 'fcmToken': fcmToken,
      };

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      name: json['name'],
      phone: json['phone'],
      relation: json['relation'],
      fcmToken: json['fcmToken'],
    );
  }
}

enum VibrationIntensity { low, medium, high }
