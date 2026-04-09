import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_model.dart';

final settingsProvider = StateNotifierProvider<SettingsController, SettingsModel>((ref) {
  return SettingsController();
});

class SettingsController extends StateNotifier<SettingsModel> {
  SettingsController()
      : super(SettingsModel(
          theme: "dark",
          units: "Metric (km/h)",
          crashSensitivity: "Medium",
          autoSOS: true,
          emergencyContacts: [],
        ));

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
  }

  // Legacy support for UI
  void setDarkMode(bool isDark) {
    state = state.copyWith(theme: isDark ? "dark" : "light");
  }

  void setUnits(String units) {
    state = state.copyWith(units: units);
  }

  void setCrashSensitivity(String level) {
    state = state.copyWith(crashSensitivity: level);
  }

  void toggleSOS(bool value) {
    state = state.copyWith(autoSOS: value);
  }

  // Legacy support for UI
  void setAutoSos(bool value) {
    state = state.copyWith(autoSOS: value);
  }

  // Emergency Contacts
  void addEmergencyContact(String contact) {
    if (!state.emergencyContacts.contains(contact)) {
      state = state.copyWith(
        emergencyContacts: [...state.emergencyContacts, contact]
      );
    }
  }

  void removeEmergencyContact(String contact) {
    state = state.copyWith(
      emergencyContacts: state.emergencyContacts.where((c) => c != contact).toList()
    );
  }
}
