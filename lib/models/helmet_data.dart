/// Indicator state enum for turn signals
enum IndicatorState { left, right, none }

/// Blink state for helmet lights
enum BlinkState { on, off }

/// Helmet data model parsed from BLE packets
/// Format: "SP:<speed>,I:<indicator>,B:<brake>,C:<crash>,LAT:<lat>,LOG:<lng>,CLK:<blink>,DEV:<raw_data>"
class HelmetDataModel {
  final double speed;
  final IndicatorState indicator;
  final bool brake;
  final bool crash;
  final double latitude;
  final double longitude;
  final BlinkState blink;
  final double ax;
  final double ay;
  final double az;
  final String rawDevData;
  final DateTime timestamp;

  HelmetDataModel({
    required this.speed,
    required this.indicator,
    required this.brake,
    required this.crash,
    required this.latitude,
    required this.longitude,
    required this.blink,
    required this.ax,
    required this.ay,
    required this.az,
    required this.rawDevData,
    required this.timestamp,
  });

  bool get isMoving => speed > 2.0;
  bool get isTurningLeft => indicator == IndicatorState.left;
  bool get isTurningRight => indicator == IndicatorState.right;
  bool get isBraking => brake;

  @override
  String toString() {
    return 'HelmetDataModel(speed: $speed, indicator: $indicator, brake: $brake, crash: $crash, lat: $latitude, lng: $longitude)';
  }
}

/// Factory to create default/empty helmet data
class HelmetDataModelEmpty {
  static HelmetDataModel get data => HelmetDataModel(
        speed: 0.0,
        indicator: IndicatorState.none,
        brake: false,
        crash: false,
        latitude: 0.0,
        longitude: 0.0,
        blink: BlinkState.off,
        ax: 0.0,
        ay: 0.0,
        az: 9.81,
        rawDevData: '',
        timestamp: DateTime.now(),
      );
}
