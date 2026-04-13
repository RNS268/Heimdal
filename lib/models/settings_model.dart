class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {"name": name, "phone": phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json["name"] as String? ?? "").trim(),
      phone: (json["phone"] as String? ?? "").trim(),
    );
  }
}

class SettingsModel {
  final String theme;
  final String units;
  final String crashSensitivity;
  final bool autoSOS;
  final String defaultMusicAppPackage;
  final List<EmergencyContact> emergencyContacts;
  final Map<String, dynamic> crashThresholds;
  final DateTime? lastSyncedAt;

  SettingsModel({
    required this.theme,
    required this.units,
    required this.crashSensitivity,
    required this.autoSOS,
    this.defaultMusicAppPackage = '',
    this.emergencyContacts = const [],
    this.crashThresholds = const {},
    this.lastSyncedAt,
  });

  factory SettingsModel.defaults() => SettingsModel(
        theme: "dark",
        units: "metric",
        crashSensitivity: "medium",
        autoSOS: true,
      );

  SettingsModel copyWith({
    String? theme,
    String? units,
    String? crashSensitivity,
    bool? autoSOS,
    String? defaultMusicAppPackage,
    List<EmergencyContact>? emergencyContacts,
    Map<String, dynamic>? crashThresholds,
    DateTime? lastSyncedAt,
  }) {
    return SettingsModel(
      theme: theme ?? this.theme,
      units: units ?? this.units,
      crashSensitivity: crashSensitivity ?? this.crashSensitivity,
      autoSOS: autoSOS ?? this.autoSOS,
      defaultMusicAppPackage: defaultMusicAppPackage ?? this.defaultMusicAppPackage,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      crashThresholds: crashThresholds ?? this.crashThresholds,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
