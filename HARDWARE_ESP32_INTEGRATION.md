# ESP32 Hardware Integration Guide

## Pin Configuration (Verified with Firmware)

### LED Indicators
- **LEFT LED**: GPIO 32
- **RIGHT LED**: GPIO 33
- **BRAKE LED**: GPIO 27

### GPS Module (UART2)
- **RX**: GPIO 16
- **TX**: GPIO 17
- **Baud Rate**: 9600

### MPU6050 (I2C Bus)
- **SDA**: GPIO 21
- **SCL**: GPIO 19
- **Address**: 0x68 (default)

### Audio (I2S + MAX98357A)
- **BCLK**: GPIO 26
- **LRC**: GPIO 25
- **DIN**: GPIO 22

## Crash Detection Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| IMPACT_THRESHOLD | 7.0g | G-force impact detection |
| SPEED_DROP_THRESHOLD | 10.0 km/h | Sudden deceleration |
| TILT_CRASH_ANGLE | 60° | Abnormal tilt angle |
| CRASH_CONFIRM_TIME | 100ms | Confirmation window |

## BLE Communication Protocol

### Service Configuration
- **Service UUID**: `12345678-1234-1234-1234-1234567890ab`
- **Characteristic UUID**: `44444444-4444-4444-4444-444444444444`
- **Device Name**: `HelmetSensor`
- **MTU**: 185 bytes
- **Property**: NOTIFY (500ms interval)

### Data Format
```
SP:<speed>,I:<indicator>,B:<brake>,C:<crash>,LAT:<latitude>,LOG:<longitude>,CLK:<blink>,DEV:<raw_data>
```

### Field Descriptions

| Field | Type | Range | Example | Notes |
|-------|------|-------|---------|-------|
| SP | Float | 0-200 | SP:45.5 | Speed in km/h |
| I | String | L/R/NONE | I:L | Left/Right indicator or None |
| B | Int | 0/1 | B:1 | 0=Not braking, 1=Braking |
| C | String | ACCT/NO | C:ACCT | ACCT=Crash detected, NO=Normal |
| LAT | Float | -90 to 90 | LAT:-23.5456 | Latitude from GPS |
| LOG | Float | -180 to 180 | LOG:151.2341 | Longitude from GPS |
| CLK | Int | 0/1 | CLK:1 | 1=LED blink ON, 0=LED blink OFF |
| DEV | String | Complex | DEV:AX:0.12,... | Raw sensor data |

### DEV String Format
```
DEV:AX:<ax>,AY:<ay>,AZ:<az>,MAG:<magnitude>,P:<pitch>,R:<roll>
```

**Example complete packet:**
```
SP:55.2,I:R,B:0,C:NO,LAT:40.7128,LOG:-74.0060,CLK:1,DEV:AX:0.45,AY:-0.12,AZ:9.78,MAG:0.5,P:2.3,R:18.5
```

## RTOS Task Configuration

### Task 1: GPS Task
- **Core**: 1
- **Priority**: 1
- **Stack**: 4096 bytes
- **Interval**: 100ms
- **Responsibility**: Parse GNSS data, update position/speed/altitude

### Task 2: Motion Task
- **Core**: 1
- **Priority**: 2 (Higher priority)
- **Stack**: 4096 bytes
- **Interval**: 50ms (20Hz sampling)
- **Responsibility**: Read MPU6050, calculate angles, detect crash

### Task 3: BLE Task
- **Core**: 1
- **Priority**: 1
- **Stack**: 4096 bytes
- **Interval**: 500ms
- **Responsibility**: Format and transmit BLE notifications

### Synchronization
- **gpsMutex**: Protects GPS data access
- **motionMutex**: Protects motion data access

## LED Control Logic

### Left Indicator (GPIO 32)
```
if (roll < -15°) → Blink at 500ms interval
if (roll ≥ -15°) → OFF
```

### Right Indicator (GPIO 33)
```
if (roll > +15°) → Blink at 500ms interval
if (roll ≤ +15°) → OFF
```

### Brake Indicator (GPIO 27)
```
if (pitch < 35°) → ON (constant, no blink)
if (pitch ≥ 35°) → OFF
```

**Blink State**: Toggle every 500ms
- Only active LEDs blink
- Never both LEFT and RIGHT simultaneously

## Crash Detection Algorithm

### Primary Triggers
1. **High Impact**: `abs(acceleration_magnitude - 9.81) > 7.0g`
2. **Sudden Stop**: `last_speed - current_speed > 10 km/h`
3. **Abnormal Tilt**: `abs(pitch) > 60° || abs(roll) > 60°`

### State Machine
```
CRASH_IDLE → [High Impact] → CRASH_POSSIBLE
           ↓ [< 100ms confirmed]
        CRASH_CONFIRMED → [Send "ACCT" via BLE]
```

### BLE Notification
- Sends `C:ACCT` when crash confirmed
- Sends `C:NO` for normal operation

## Sensor Interpretation

### Pitch Angle (Forward/Backward Tilt)
```
pitch = atan2(AX, sqrt(AY² + AZ²)) * 180 / π
```
- **< 35°**: Braking detected
- **> 60°**: Extreme tilt (possible crash)

### Roll Angle (Left/Right Tilt)
```
roll = atan2(AY, sqrt(AX² + AZ²)) * 180 / π
```
- **< -15°**: Left turn indicator
- **> +15°**: Right turn indicator

### G-Force Impact
```
g_force = |magnitude - 9.81|
where magnitude = sqrt(AX² + AY² + AZ²)
```
- Threshold: 7.0g for crash detection

## Flutter App Integration

### Data Reception
The Flutter `Parser` class handles:
1. ✅ Speed parsing from `SP` field
2. ✅ Indicator state from `I` field (L/R/NONE)
3. ✅ Brake state from `B` field (0/1)
4. ✅ **Crash detection from `C` field (ACCT/NO)**
5. ✅ GPS coordinates from `LAT`/`LOG` fields
6. ✅ LED blink state from `CLK` field
7. ✅ Raw acceleration data from `DEV` field

### Updated Parser Support
- Correctly handles `C:ACCT` for crash confirmation
- Correctly handles `C:NO` for normal operation
- Extracts AX/AY/AZ from DEV string for sensor fusion
- Maintains backward compatibility with numeric crash flags

## Testing Checklist

- [ ] GPS provides coordinates and speed at 10Hz
- [ ] MPU6050 reads acceleration at 20Hz
- [ ] LEFT LED blinks when roll < -15°
- [ ] RIGHT LED blinks when roll > +15°
- [ ] BRAKE LED solid when pitch < 35°
- [ ] Crash detection triggers on high impact
- [ ] BLE transmits all fields correctly
- [ ] Audio A2DP works independently
- [ ] No RTOS task starvation
- [ ] Crash state sends "ACCT" to mobile app
- [ ] Mobile app properly detects crash and triggers SOS UI

## Firmware Version
- **Last Updated**: April 10, 2026
- **Hardware**: ESP32-DevKit-V1
- **Arduino Framework**: 2.0+
- **Libraries**: TinyGPS++, Adafruit_MPU6050, BLE, AudioTools, BluetoothA2DPSink
