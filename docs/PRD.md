# Product Requirements Document: HEIMDALL Smart Helmet System

## 1. Vision & Purpose
HEIMDALL is an advanced motorcycle safety and telemetry ecosystem. It bridges the gap between helmet-mounted hardware (ESP32) and the rider's mobile dashboard via Bluetooth Low Energy (BLE), providing real-time HUD metrics, hybrid GPS tracking, and automatic SOS capabilities during crash events.

## 2. Core Features (MVP)

### 2.1 Connectivity & Data Parser
*   **BLE Protocol**: Establish a robust connection to `ESP32-Helmet-V4`.
*   **Telemetric Parsing**: Interpret string-based sensor data from `helmet_data.dart`.
*   **Heartbeat Monitor**: Visual connection status for helmet sensors and audio headsets.

### 2.2 Live HUD Dashboard
*   **Dynamic Speedmeter**: Large, readable speed display with unit switching (km/h).
*   **Active Indicators**: Visual mirroring of the helmet's left/right turn signals.
*   **Brake Alert System**: Immediate visual warning when deceleration sensors trigger.
*   **Telemetric Overlays**: Map-based navigation cues (distance to next turn, street names).

### 2.3 Intelligent Safety (Crash Detection)
*   **Impact Thresholds**: Real-time monitoring of helmet G-force/accelerometer data.
*   **SOS Countdown**: Visual 10-second interruptible timer.
*   **Autonomous SOS**: Automatic transmission of GPS coordinates to emergency contacts upon confirmed crash.
*   **Collision Visualizer**: Post-impact summary overlay for incident documentation.

### 2.4 Ride Tracking & Hybrid GPS
*   **Path Mapping**: Accurate ride tracing using `google_maps_flutter`.
*   **Hybrid Fallback**: Seamlessly switch between phone and helmet GPS data streams for maximum signal reliability.
*   **Live Metrics**: Session-based tracking of distance, duration, and average speeds.

### 2.5 Integrated Controls
*   **Music Hub**: Playback controls (Play/Pause/Skip) for helmet-mounted speakers.
*   **Environment Configuration**: User-defined thresholds for crash detection and sensor sensitivity.

## 3. Technical Stack
*   **Frontend**: Flutter (Dart)
*   **State Management**: Riverpod with Generator support.
*   **BLE Engine**: `flutter_blue_plus`
*   **Mapping Engine**: `google_maps_flutter`
*   **Permissions**: Comprehensive handler for Location, Bluetooth, and Emergency status.

## 4. UI/UX Principles
*   **Glassmorphism Dashboard**: High-transparency, blurred background cards for a futuristic aesthetic.
*   **Safety-First Visibility**: High-contrast colors (Crimson for alerts, Cyan for telemetry) optimized for daylight and nighttime riding.
*   **Immersive Navigation**: Minimalist bottom bar with easy-access tabs (Home, Maps, Music, Raw Data).

## 5. Development Roadmap (Next Tasks)
1.  **Refine BLE Reconnection Logic**: Implement exponential backoff for dropped helmet connections.
2.  **Optimize Map Rendering**: Enhance ride-path polyline smoothing.
3.  **Finalize Crash Sensor Simulation**: Test SOS triggers with mock sensor data.
