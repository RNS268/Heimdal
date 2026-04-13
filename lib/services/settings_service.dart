import "dart:convert";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/settings_model.dart";
import "settings_api_service.dart";

const _prefsKey = "heimdall.settings.v2";
const _fallbackEmergency = "112";

final settingsApiServiceProvider = Provider<SettingsApiService>((ref) {
  return SettingsApiService(
    baseUrl: const String.fromEnvironment(
      "SETTINGS_API_BASE_URL",
      defaultValue: "http://10.0.2.2:3000",
    ),
    userId: const String.fromEnvironment(
      "SETTINGS_USER_ID",
      defaultValue: "android-user",
    ),
  );
});

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsModel>((ref) {
      return SettingsController(ref.read(settingsApiServiceProvider));
    });

class SettingsController extends StateNotifier<SettingsModel> {
  SettingsController(this._api) : super(SettingsModel.defaults()) {
    load();
  }

  final SettingsApiService _api;

  static const sensitivityThresholdPreview = {
    "low": {"g_force": ">= 6.0g", "speed_drop": ">= 35%"},
    "medium": {"g_force": ">= 4.5g", "speed_drop": ">= 25%"},
    "high": {"g_force": ">= 3.5g", "speed_drop": ">= 15%"},
  };

  Future<void> load() async {
    await _loadFromPrefs();
    await syncFromBackend();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    state = _fromFlatJson(map).copyWith(
      crashThresholds:
          sensitivityThresholdPreview[state.crashSensitivity] ?? const {},
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_toFlatJson(state)));
  }

  Future<void> syncFromBackend() async {
    try {
      final app =
          (await _api.getJson("/settings/app"))["data"] as Map<String, dynamic>;
      final safety =
          (await _api.getJson("/settings/safety"))["data"]
              as Map<String, dynamic>;
      final contacts =
          (await _api.getJson("/settings/emergency-contacts"))["data"]
              as Map<String, dynamic>;

      state = state.copyWith(
        theme: (app["theme"] as String? ?? "dark"),
        units: (app["units"] as String? ?? "metric"),
        crashSensitivity: (safety["crash_sensitivity"] as String? ?? "medium"),
        autoSOS: (safety["auto_sos"] as bool? ?? true),
        crashThresholds:
            (safety["thresholds"] as Map<String, dynamic>? ?? const {}),
        emergencyContacts: ((contacts["contacts"] as List<dynamic>? ?? const [])
            .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
            .toList()),
        lastSyncedAt: DateTime.now(),
      );
      await _persist();
    } catch (_) {
      // Keep local state when backend is unreachable.
    }
  }

  Future<void> setTheme(String theme) async {
    state = state.copyWith(theme: theme);
    await _persist();
    await _api.postJson("/settings/app", {"theme": theme});
  }

  Future<void> setUnits(String units) async {
    state = state.copyWith(units: units);
    await _persist();
    await _api.postJson("/settings/app", {"units": units});
  }

  Future<void> setCrashSensitivity(String level) async {
    state = state.copyWith(
      crashSensitivity: level,
      crashThresholds: sensitivityThresholdPreview[level] ?? const {},
    );
    await _persist();
    final data =
        (await _api.postJson("/settings/safety", {
              "crash_sensitivity": level,
            }))["data"]
            as Map<String, dynamic>;
    state = state.copyWith(
      crashThresholds: data["thresholds"] as Map<String, dynamic>? ?? const {},
    );
    await _persist();
  }

  Future<void> setAutoSos(bool value) async {
    state = state.copyWith(autoSOS: value);
    await _persist();
    await _api.postJson("/settings/safety", {"auto_sos": value});
  }

  Future<void> setDefaultMusicApp(String package) async {
    state = state.copyWith(defaultMusicAppPackage: package);
    await _persist();
  }

  String normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r"[^\d+]"), "");
    if (cleaned.startsWith("+")) return cleaned;
    if (cleaned.length == 10) return "+1$cleaned";
    if (cleaned.length >= 11) return "+$cleaned";
    throw Exception("Invalid phone number");
  }

  Future<String?> addEmergencyContact(String name, String phone) async {
    if (state.emergencyContacts.length >= 5) {
      return "Maximum 5 contacts allowed";
    }
    if (name.trim().isEmpty) {
      return "Contact name is required";
    }

    final normalized = normalizePhone(phone);
    final dedupe = state.emergencyContacts.any((c) => c.phone == normalized);
    if (dedupe) {
      return "Duplicate contact not allowed";
    }

    final next = [
      ...state.emergencyContacts,
      EmergencyContact(name: name.trim(), phone: normalized),
    ];
    state = state.copyWith(emergencyContacts: next);
    await _persist();
    await _pushContacts(next);
    return null;
  }

  Future<void> removeEmergencyContact(EmergencyContact contact) async {
    final next = state.emergencyContacts
        .where((c) => c.phone != contact.phone)
        .toList();
    state = state.copyWith(emergencyContacts: next);
    await _persist();
    await _pushContacts(next);
  }

  Future<void> _pushContacts(List<EmergencyContact> contacts) async {
    await _api.postJson("/settings/emergency-contacts", {
      "contacts": contacts.map((c) => c.toJson()).toList(),
    });
  }

  bool get hasFallbackOnly => state.emergencyContacts.isEmpty;
  String get fallbackEmergency => _fallbackEmergency;

  static Map<String, dynamic> _toFlatJson(SettingsModel s) => {
    "theme": s.theme,
    "units": s.units,
    "crashSensitivity": s.crashSensitivity,
    "autoSOS": s.autoSOS,
    "defaultMusicAppPackage": s.defaultMusicAppPackage,
    "contacts": s.emergencyContacts.map((e) => e.toJson()).toList(),
    "crashThresholds": s.crashThresholds,
  };

  static SettingsModel _fromFlatJson(Map<String, dynamic> map) {
    return SettingsModel(
      theme: (map["theme"] as String? ?? "dark"),
      units: (map["units"] as String? ?? "metric"),
      crashSensitivity: (map["crashSensitivity"] as String? ?? "medium"),
      autoSOS: (map["autoSOS"] as bool? ?? true),
      defaultMusicAppPackage: (map["defaultMusicAppPackage"] as String? ?? ""),
      emergencyContacts: ((map["contacts"] as List<dynamic>? ?? const [])
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList()),
      crashThresholds:
          map["crashThresholds"] as Map<String, dynamic>? ?? const {},
    );
  }
}
