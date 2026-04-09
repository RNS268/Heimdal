import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'settings_service.dart';

class EmergencyAlertService {
  final Ref _ref;

  EmergencyAlertService(this._ref);

  /// Get first contact from settings, fallback to 112
  String _primaryContact() {
    final contacts = _ref.read(settingsProvider).emergencyContacts;
    return contacts.isNotEmpty ? contacts.first : '112';
  }

  List<String> _allContacts() {
    final contacts = _ref.read(settingsProvider).emergencyContacts;
    return contacts.isNotEmpty ? contacts : ['112'];
  }

  /// Make emergency phone call to first contact
  Future<bool> callEmergencyContact() async {
    try {
      final number = _primaryContact();
      final telUri = Uri(scheme: 'tel', path: number);
      return await launchUrl(telUri);
    } catch (e) {
      return false;
    }
  }

  /// Send SMS to ALL emergency contacts with location
  Future<void> sendCrashAlerts({
    required double latitude,
    required double longitude,
  }) async {
    final contacts = _allContacts();
    final mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';
    final message =
        'CRASH ALERT: I may have had an accident. My location: $mapsUrl';

    try {
      await sendSMS(
        message: message,
        recipients: contacts,
      );
    } catch (_) {}
  }
}

final emergencyAlertServiceProvider = Provider<EmergencyAlertService>((ref) {
  return EmergencyAlertService(ref);
});
