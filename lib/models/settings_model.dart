class SettingsModel {
  final String theme;
  final String units;
  final String crashSensitivity;
  final bool autoSOS;
  final List<String> emergencyContacts;

  SettingsModel({
    required this.theme,
    required this.units,
    required this.crashSensitivity,
    required this.autoSOS,
    this.emergencyContacts = const [],
  });

  SettingsModel copyWith({
    String? theme,
    String? units,
    String? crashSensitivity,
    bool? autoSOS,
    List<String>? emergencyContacts,
  }) {
    return SettingsModel(
      theme: theme ?? this.theme,
      units: units ?? this.units,
      crashSensitivity: crashSensitivity ?? this.crashSensitivity,
      autoSOS: autoSOS ?? this.autoSOS,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }
}
