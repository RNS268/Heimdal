import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'settings_service.dart';
import 'phone_call_service.dart';

class EmergencyAlertService {
  final Ref _ref;

  EmergencyAlertService(this._ref);

  /// Get first contact from settings, fallback to 112
  String _primaryContact() {
    final contacts = _ref.read(settingsProvider).emergencyContacts;
    return contacts.isNotEmpty ? contacts.first.phone : '112';
  }

  List<String> _allContacts() {
    final contacts = _ref.read(settingsProvider).emergencyContacts;
    return contacts.isNotEmpty
        ? contacts.map((c) => c.phone).toList()
        : ['112'];
  }

  /// Make emergency phone call to first contact using platform channel
  /// Returns true if call was successfully initiated
  Future<bool> callEmergencyContact({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final number = _primaryContact();
      final phoneCallService = _ref.read(phoneCallServiceProvider);

      return await phoneCallService.makeEmergencyCall(
        phoneNumber: number,
        contactName: 'Emergency Contact',
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      print('❌ [EMERGENCY] Call error: $e');
      return false;
    }
  }

  /// Try calling all emergency contacts with retry logic
  Future<String?> callAllEmergencyContacts({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final contacts = _ref.read(settingsProvider).emergencyContacts;

      if (contacts.isEmpty) {
        print('⚠️ [EMERGENCY] No contacts - calling 112');
        final phoneCallService = _ref.read(phoneCallServiceProvider);
        final success = await phoneCallService.callEmergencyServices(
          latitude: latitude,
          longitude: longitude,
        );
        return success ? '112' : null;
      }

      final phoneCallService = _ref.read(phoneCallServiceProvider);
      final contactList = contacts
          .map((contact) => {'phone': contact.phone, 'name': contact.name})
          .toList();

      return await phoneCallService.callMultipleContacts(
        contacts: contactList,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      print('❌ [EMERGENCY] Multiple call error: $e');
      return null;
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
      await sendSMS(message: message, recipients: contacts);
    } catch (_) {}
  }
}

final emergencyAlertServiceProvider = Provider<EmergencyAlertService>((ref) {
  return EmergencyAlertService(ref);
});
