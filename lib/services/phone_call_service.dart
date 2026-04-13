import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform channel for making emergency phone calls on Android/iOS
class PhoneCallService {
  static const platform = MethodChannel('com.heimdall.helmet/emergency_calls');

  /// Make an emergency phone call
  /// Returns true if call was initiated successfully
  Future<bool> makeEmergencyCall({
    required String phoneNumber,
    required String contactName,
    required double latitude,
    required double longitude,
  }) async {
    try {
      print('📞 [CALL] Initiating emergency call to $contactName ($phoneNumber)');
      
      final result = await platform.invokeMethod<bool>(
        'makeEmergencyCall',
        {
          'phoneNumber': phoneNumber,
          'contactName': contactName,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      
      if (result == true) {
        print('✓ [CALL] Emergency call initiated successfully');
        return true;
      } else {
        print('✗ [CALL] Failed to initiate emergency call');
        return false;
      }
    } on PlatformException catch (e) {
      print('✗ [CALL] Platform error: ${e.message}');
      return false;
    } catch (e) {
      print('✗ [CALL] Unexpected error: $e');
      return false;
    }
  }

  /// Retry call to another number if first call fails
  Future<bool> callWithRetry({
    required String phoneNumber,
    required String contactName,
    required double latitude,
    required double longitude,
    required int maxRetries,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('📞 [CALL] Attempt $attempt/$maxRetries to $contactName');
      
      final success = await makeEmergencyCall(
        phoneNumber: phoneNumber,
        contactName: contactName,
        latitude: latitude,
        longitude: longitude,
      );
      
      if (success) {
        return true;
      }
      
      // Wait before retry
      if (attempt < maxRetries) {
        final waitSeconds = 2 * attempt; // 2s, 4s, 6s...
        print('⏳ [CALL] Retrying in ${waitSeconds}s...');
        await Future.delayed(Duration(seconds: waitSeconds));
      }
    }
    
    print('✗ [CALL] All retry attempts failed');
    return false;
  }

  /// Call multiple contacts sequentially until one succeeds
  Future<String?> callMultipleContacts({
    required List<Map<String, String>> contacts, // [{phone, name}, ...]
    required double latitude,
    required double longitude,
  }) async {
    print('📞 [CALL] Attempting to reach ${contacts.length} contacts...');
    
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final phone = contact['phone']!;
      final name = contact['name']!;
      
      print('📞 [CALL] Trying contact ${i + 1}/${contacts.length}: $name');
      
      final success = await makeEmergencyCall(
        phoneNumber: phone,
        contactName: name,
        latitude: latitude,
        longitude: longitude,
      );
      
      if (success) {
        print('✓ [CALL] Successfully reached: $name');
        return name;
      }
      
      // Wait between attempts
      if (i < contacts.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    print('✗ [CALL] Failed to reach any contact');
    return null;
  }

  /// Call emergency services (112/911)
  Future<bool> callEmergencyServices({
    required double latitude,
    required double longitude,
  }) async {
    print('📞 [CALL] Calling emergency services...');
    
    return await makeEmergencyCall(
      phoneNumber: '112', // EU standard
      contactName: 'Emergency Services',
      latitude: latitude,
      longitude: longitude,
    );
  }
}

final phoneCallServiceProvider = Provider<PhoneCallService>((ref) {
  return PhoneCallService();
});
