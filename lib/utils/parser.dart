import '../models/helmet_data.dart';

/// Parser for BLE data packets
/// Format: "SP:<speed>,I:<indicator>,B:<brake>,C:<crash>,LAT:<lat>,LOG:<lng>,CLK:<blink>,DEV:<raw_data>"
class Parser {
  static HelmetDataModel? parse(String dataString) {
    try {
      final trimmed = dataString.trim();
      if (trimmed.isEmpty) return null;

      double speed = 0.0;
      IndicatorState indicator = IndicatorState.none;
      bool brake = false;
      bool crash = false;
      double latitude = 0.0;
      double longitude = 0.0;
      double ax = 0.0;
      double ay = 0.0;
      double az = 9.81;
      BlinkState blink = BlinkState.off;
      String rawDevData = '';

      // Split by comma, but handle DEV field specially (it may contain commas within its value)
      final parts = <String>[];
      String? devBuffer;
      
      for (final part in trimmed.split(',')) {
        if (part.startsWith('DEV:')) {
          devBuffer = part;
        } else if (devBuffer != null) {
          // Continue accumulating DEV data
          devBuffer += ',$part';
          // Check if this looks like end of DEV (check for known closing patterns)
          if (part.contains('R:')) {
            // Likely end of DEV string
            parts.add(devBuffer);
            devBuffer = null;
          }
        } else {
          parts.add(part);
        }
      }
      
      // Add any remaining DEV buffer
      if (devBuffer != null) {
        parts.add(devBuffer);
      }

      for (final part in parts) {
        final kv = part.split(':');
        if (kv.length < 2) continue;

        final key = kv[0].trim().toUpperCase();
        final value = kv[1].trim();
        final valueUpper = value.toUpperCase();

        switch (key) {
          case 'SP':
            speed = double.tryParse(value) ?? 0.0;
          case 'I':
            switch (valueUpper) {
              case 'L':
                indicator = IndicatorState.left;
              case 'R':
                indicator = IndicatorState.right;
              default:
                indicator = IndicatorState.none;
            }
          case 'B':
            brake = value == '1';
          case 'C':
            crash = valueUpper == 'ACCT';
          case 'LAT':
            latitude = double.tryParse(value) ?? 0.0;
          case 'LOG':
            longitude = double.tryParse(value) ?? 0.0;
          case 'CLK':
            blink = value == '1' ? BlinkState.on : BlinkState.off;
          case 'DEV':
            // DEV value is everything after "DEV:"
            rawDevData = part.substring(4); // Skip "DEV:"
            _parseDevInfo(rawDevData, (aVal, ayVal, azVal) {
              ax = aVal;
              ay = ayVal;
              az = azVal;
            });
        }
      }

      return HelmetDataModel(
        speed: speed,
        indicator: indicator,
        brake: brake,
        crash: crash,
        latitude: latitude,
        longitude: longitude,
        blink: blink,
        ax: ax,
        ay: ay,
        az: az,
        rawDevData: rawDevData,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse DEV string: "AX:<ax>,AY:<ay>,AZ:<az>,MAG:<mag>,P:<pitch>,R:<roll>"
  static void _parseDevInfo(String devInfo, Function(double, double, double) onParsed) {
    try {
      double ax = 0.0, ay = 0.0, az = 9.81;
      
      final devParts = devInfo.split(',');
      for (final part in devParts) {
        final kv = part.split(':');
        if (kv.length != 2) continue;
        
        final key = kv[0].trim().toUpperCase();
        final value = double.tryParse(kv[1].trim()) ?? 0.0;
        
        switch (key) {
          case 'AX':
            ax = value;
          case 'AY':
            ay = value;
          case 'AZ':
            az = value;
        }
      }
      
      onParsed(ax, ay, az);
    } catch (_) {
      // Silent fail, use defaults
    }
  }

  static String toPacketString(HelmetDataModel data) {
    final indicatorStr = switch (data.indicator) {
      IndicatorState.left => 'L',
      IndicatorState.right => 'R',
      IndicatorState.none => 'NONE',
    };

    final crashStr = data.crash ? 'ACCT' : 'NO';

    return 'SP:${data.speed},'
        'I:$indicatorStr,'
        'B:${data.brake ? 1 : 0},'
        'C:$crashStr,'
        'LAT:${data.latitude},'
        'LOG:${data.longitude},'
        'CLK:${data.blink == BlinkState.on ? 1 : 0},'
        'DEV:${data.rawDevData}';
  }
}
