/// Hardware Integration Tests
/// Tests to verify ESP32 firmware data is correctly parsed and handled by Flutter app

import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/models/helmet_data.dart';
import 'package:heimdall/utils/parser.dart';

void main() {
  group('ESP32 Firmware Integration', () {
    group('BLE Data Format Parsing', () {
      test('Parse speed (SP) field correctly', () {
        const data =
            'SP:55.2,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.1,AY:0.2,AZ:9.81';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.speed, equals(55.2));
      });

      test('Parse crash status ACCT (crash confirmed)', () {
        const data =
            'SP:0.0,I:NONE,B:0,C:ACCT,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:8.5,AY:0.2,AZ:1.2';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.crash, equals(true), reason: 'ACCT should indicate crash');
      });

      test('Parse crash status NO (no crash)', () {
        const data =
            'SP:45.0,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.1,AY:0.2,AZ:9.81';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.crash, equals(false), reason: 'NO should indicate no crash');
      });

      test('Parse left indicator', () {
        const data =
            'SP:30.0,I:L,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.1,AY:-18.5,AZ:5.2';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.indicator, equals(IndicatorState.left));
      });

      test('Parse right indicator', () {
        const data =
            'SP:30.0,I:R,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.1,AY:18.5,AZ:5.2';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.indicator, equals(IndicatorState.right));
      });

      test('Parse brake state (pitch < 35 degrees)', () {
        const data =
            'SP:50.0,I:NONE,B:1,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:8.2,AY:0.0,AZ:2.0';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.brake, equals(true));
      });

      test('Parse GPS coordinates', () {
        const data =
            'SP:45.5,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.1,AY:0.2,AZ:9.81';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.latitude, equals(40.7128));
        expect(result?.longitude, equals(-74.0060));
      });

      test('Parse LED blink state', () {
        const data1 =
            'SP:0.0,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.1,AY:0.2,AZ:9.81';
        final result1 = Parser.parse(data1);
        expect(result1?.blink, equals(BlinkState.on));

        const data0 =
            'SP:0.0,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.1,AY:0.2,AZ:9.81';
        final result0 = Parser.parse(data0);
        expect(result0?.blink, equals(BlinkState.off));
      });

      test('Extract acceleration from DEV field', () {
        const data =
            'SP:0.0,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.45,AY:-0.12,AZ:9.78,MAG:0.5,P:2.3,R:18.5';
        final result = Parser.parse(data);

        expect(result, isNotNull);
        expect(result?.ax, closeTo(0.45, 0.01));
        expect(result?.ay, closeTo(-0.12, 0.01));
        expect(result?.az, closeTo(9.78, 0.01));
      });
    });

    group('Crash Detection Edge Cases', () {
      test('Detect crash with high impact (> 7g)', () {
        const data =
            'SP:0.0,I:NONE,B:0,C:ACCT,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:7.5,AY:3.2,AZ:1.1';
        final result = Parser.parse(data);

        expect(result?.crash, equals(true),
            reason: 'High impact with ACCT should be crash');
      });

      test('Detect crash with sudden stop', () {
        const data =
            'SP:0.0,I:NONE,B:1,C:ACCT,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.5,AY:0.2,AZ:9.81';
        final result = Parser.parse(data);

        expect(result?.crash, equals(true),
            reason: 'Brake engaged with ACCT should be crash');
      });

      test('Parse extreme pitch (crash scenario)', () {
        const data =
            'SP:0.0,I:NONE,B:1,C:ACCT,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:8.9,AY:0.1,AZ:0.5,MAG:8.9,P:85.2,R:0.5';
        final result = Parser.parse(data);

        expect(result?.crash, equals(true));
        expect(result?.brake, equals(true));
      });
    });

    group('Indicator Logic (Roll Angle)', () {
      test('Left turn when roll < -15 degrees', () {
        const data =
            'SP:30.0,I:L,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.5,AY:-2.5,AZ:9.5,P:0.0,R:-18.5';
        final result = Parser.parse(data);

        expect(result?.indicator, equals(IndicatorState.left));
      });

      test('Right turn when roll > +15 degrees', () {
        const data =
            'SP:30.0,I:R,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.5,AY:2.5,AZ:9.5,P:0.0,R:18.5';
        final result = Parser.parse(data);

        expect(result?.indicator, equals(IndicatorState.right));
      });

      test('No turn when roll between -15 and +15 degrees', () {
        const data =
            'SP:30.0,I:NONE,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:0.5,AY:0.0,AZ:9.8,P:0.0,R:5.0';
        final result = Parser.parse(data);

        expect(result?.indicator, equals(IndicatorState.none));
      });
    });

    group('Complete Packet Format Validation', () {
      test('Parse complete valid packet (normal operation)', () {
        const packet =
            'SP:65.3,I:R,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.12,AY:16.5,AZ:5.2,MAG:17.1,P:3.5,R:21.3';
        final result = Parser.parse(packet);

        expect(result, isNotNull);
        expect(result?.speed, equals(65.3));
        expect(result?.indicator, equals(IndicatorState.right));
        expect(result?.brake, equals(false));
        expect(result?.crash, equals(false));
        expect(result?.latitude, equals(40.7128));
        expect(result?.longitude, equals(-74.0060));
        expect(result?.blink, equals(BlinkState.on));
        expect(result?.ax, closeTo(0.12, 0.01));
        expect(result?.ay, closeTo(16.5, 0.1));
        expect(result?.az, closeTo(5.2, 0.1));
      });

      test('Parse complete valid packet (crash detected)', () {
        const packet =
            'SP:0.0,I:NONE,B:1,C:ACCT,LAT:40.7128,LOG:-74.0060,CLK:0,DEV:AX:8.2,AY:0.3,AZ:1.5,MAG:8.3,P:82.1,R:2.3';
        final result = Parser.parse(packet);

        expect(result, isNotNull);
        expect(result?.speed, equals(0.0));
        expect(result?.brake, equals(true));
        expect(result?.crash, equals(true),
            reason: 'C:ACCT indicates crash confirmed');
        expect(result?.latitude, equals(40.7128));
        expect(result?.longitude, equals(-74.0060));
      });
    });

    group('Packet Generation (Reverse)', () {
      test('Generate packet from model (normal state)', () {
        final model = HelmetDataModel(
          speed: 45.5,
          indicator: IndicatorState.left,
          brake: false,
          crash: false,
          latitude: 40.7128,
          longitude: -74.0060,
          blink: BlinkState.on,
          ax: 0.1,
          ay: -18.5,
          az: 5.2,
          rawDevData: 'AX:0.1,AY:-18.5,AZ:5.2',
          timestamp: DateTime.now(),
        );

        final packet = Parser.toPacketString(model);

        expect(packet, contains('SP:45.5'));
        expect(packet, contains('I:L'));
        expect(packet, contains('B:0'));
        expect(packet, contains('C:NO'));
        expect(packet, contains('CLK:1'));
      });

      test('Generate packet from model (crash state)', () {
        final model = HelmetDataModel(
          speed: 0.0,
          indicator: IndicatorState.none,
          brake: true,
          crash: true,
          latitude: 40.7128,
          longitude: -74.0060,
          blink: BlinkState.off,
          ax: 8.5,
          ay: 0.2,
          az: 1.2,
          rawDevData: 'AX:8.5,AY:0.2,AZ:1.2',
          timestamp: DateTime.now(),
        );

        final packet = Parser.toPacketString(model);

        expect(packet, contains('C:ACCT'),
            reason: 'Crash should generate ACCT status');
        expect(packet, contains('B:1'));
      });
    });
  });
}
