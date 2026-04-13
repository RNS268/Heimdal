import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';
import 'phone_call_service.dart';

class EmergencyAlertService {
  final Ref _ref;
  static const MethodChannel _smsChannel =
      MethodChannel('com.heimdall.helmet/emergency_calls');

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

  Future<bool> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> _sendDirectSms({
    required String message,
    required List<String> recipients,
  }) async {
    if (!await _requestSmsPermission()) {
      print('❌ [EMERGENCY] SMS permission denied');
      return false;
    }

    try {
      final result = await _smsChannel.invokeMethod<bool>(
        'sendEmergencySms',
        {
          'message': message,
          'recipients': recipients,
        },
      );
      return result == true;
    } on PlatformException catch (e) {
      print('❌ [EMERGENCY] SMS platform error: ${e.message}');
      return false;
    } catch (e) {
      print('❌ [EMERGENCY] SMS send error: $e');
      return false;
    }
  }

  /// Send SMS to ALL emergency contacts with location
  Future<bool> sendCrashAlerts({
    required double latitude,
    required double longitude,
  }) async {
    final contacts = _allContacts();
    final mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';
    final message =
        'CRASH ALERT: I may have had an accident. My location: $mapsUrl';

    return await _sendDirectSms(message: message, recipients: contacts);
  }
}

final emergencyAlertServiceProvider = Provider<EmergencyAlertService>((ref) {
  return EmergencyAlertService(ref);
});
