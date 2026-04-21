
# 🪖 HEIMDALL
### Smart Motorcycle Helmet System

*Flutter · ESP32-S3 · BLE · GPS · Crash Detection*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![ESP32-S3](https://img.shields.io/badge/ESP32--S3-Firmware-E7352C?logo=espressif)](https://www.espressif.com)
[![BLE](https://img.shields.io/badge/Communication-BLE%205.0-0082FC)](https://www.bluetooth.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## Overview

HEIMDALL is a production-grade smart motorcycle helmet system that pairs an ESP32-S3 microcontroller embedded in the helmet with a Flutter mobile app over BLE. It provides real-time crash detection, GPS tracking, LED turn signal control, and live sensor telemetry — all through a purpose-built app with a glassmorphic dark UI called **The Precision Pilot**.

Built as a competition-grade engineering project at the **Government Institute of Electronics**.

---

## Features

**| Feature                  | Description                                                  |**
|--------------------------|--------------------------------------------------------------**|**
| 🚨 **Crash Detection**   | Gyroscope-based impact & fall detection with automatic alert |
| 📍 **GPS Tracking**      | Real-time location tracking with map integration             |
| 💡 **LED Signaling**     | BLE-controlled turn signals and brake lights                 |
| 📡 **BLE Communication** | Low-latency Bluetooth 5.0 link between helmet and phone      |
| 🎵 **Music Controls**    | Helmet-integrated playback controls forwarded via BLE        |
| 📊 **Raw Sensor Data**   | Live IMU telemetry stream for debugging and logging          |

---

## System Architecture

```
┌─────────────────────────────┐         BLE 5.0         ┌──────────────────────────┐
│        ESP32-S3 Helmet      │◄───────────────────────►│     Flutter Mobile App   │
│                             │                         │                          │
│  • MPU6050 Gyroscope/Accel  │                         │  • Home Dashboard        │
│  • GPS Module               │                         │  • Accident Detection    │
│  • WS2812 LED Strip         │                         │  • GPS Tracking          │
│  • Crash Detection Logic    │                         │  • Music Controls        │
│  • FreeRTOS Tasks           │                         │  • Raw Data View         │
└─────────────────────────────┘                         │  • Settings              │
                                                        └──────────────────────────┘
```

---

## Hardware Components

- **Microcontroller** — ESP32-S3 (dual-core, BLE 5.0)
- **IMU** — MPU6050 (6-axis gyroscope + accelerometer)
- **GPS** — UART GPS module
- **LEDs** — WS2812B addressable LED strip (turn signals / brake)
- **Power** — LiPo battery with 3.3V regulation

---

## Flutter App — The Precision Pilot

The mobile app uses a custom design system called **The Precision Pilot** with:

- Full glassmorphism UI (blurred layered panels, no borders, no dividers)
- 22+ semantic hex color tokens (dark navy base, amber/teal accents)
- Six screens connected via BLE real-time data streams

### Screens

1. **Home Dashboard** — Connection status, helmet state, quick stats
2. **Accident Detection** — Live crash alert feed, sensitivity settings, emergency contact trigger
3. **GPS Tracking** — Real-time map view with location history
4. **Music Controls** — Playback control forwarded through BLE
5. **Raw Data** — Live IMU & GPS telemetry for diagnostics
6. **Settings** — BLE device pairing, alert thresholds, LED config

---

## Firmware

Written in C++ using the ESP-IDF / Arduino framework for ESP32-S3.

### Key Implementation Notes

- **Task Watchdog fix** — `esp_task_wdt_deinit()` must be called *before* BLE stack initialization to prevent TWDT resets on ESP32-S3
- **MTU Configuration** — MTU must be set after BLE connection establishment, not during stack init
- **FreeRTOS tasks** — Sensor reading, BLE TX, and LED control run as separate pinned tasks to prevent blocking

### BLE Profile

| Service | Characteristic | Direction | Description         |
|----------|---------------|-----------|---------------------|
| `0x180D` | `0x2A37`      | Notify    | IMU sensor stream   |
| `0x1819` | `0x2A67`      | Notify    | GPS location        |
| `0xFF01` | `0xFF02`      | Write     | LED command         |
| `0xFF01` | `0xFF03`      | Notify    | Crash alert         |

---

## Project Structure

```
Heimdal/
├── firmware/                # ESP32-S3 Arduino/ESP-IDF code
│   ├── src/
│   │   ├── main.cpp
│   │   ├── ble_handler.cpp
│   │   ├── crash_detect.cpp
│   │   ├── gps_handler.cpp
│   │   └── led_control.cpp
│   └── platformio.ini
│
└── app/                     # Flutter mobile app
    ├── lib/
    │   ├── screens/
    │   │   ├── home_dashboard.dart
    │   │   ├── accident_detection.dart
    │   │   ├── gps_tracking.dart
    │   │   ├── music_controls.dart
    │   │   ├── raw_data.dart
    │   │   └── settings.dart
    │   ├── services/
    │   │   └── ble_service.dart
    │   └── theme/
    │       └── precision_pilot_theme.dart
    └── pubspec.yaml
```

---

## Getting Started

### Firmware

1. Install [PlatformIO](https://platformio.org/) or Arduino IDE with ESP32-S3 board support
2. Clone the repo and open `firmware/`
3. Set your BLE service UUIDs in `ble_handler.cpp` if needed
4. Flash to your ESP32-S3:
```bash
pio run --target upload
```

### Flutter App

1. Make sure Flutter 3.x is installed
2. Navigate to `app/` and install dependencies:
```bash
flutter pub get
```
3. Run on a connected Android/iOS device:
```bash
flutter run
```
> BLE scanning requires **Location** and **Bluetooth** permissions on Android.

---

## Demo

> *(Add a GIF or screenshot here once UI is finalized)*

---

## Author

**Shashank** — [@RNS268](https://github.com/RNS268)
Diploma in Electronics · Government Institute of Electronics

---

## License

MIT License — see [LICENSE](LICENSE) for details.
