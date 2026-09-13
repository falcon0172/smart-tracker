# Implementation Status Report — Phase 1 Companion App

## Milestone 1: Foundation & Core Protocol

| Status | Feature / Component | Description |
| :---: | :--- | :--- |
| **Implemented** | Environment Setup | Flutter 3.47.4, Dart 3.13.3, JDK 17, Android SDK 36 configured & verified |
| **Implemented** | Protocol Specification | 20-byte binary BLE v1 contract specification (`protocol/v1.md`) |
| **Implemented** | Golden Test Fixtures | `protocol/fixtures/motion_golden.json` |
| **Implemented** | Architecture Documentation | Architecture, Windows, iOS, and Hardware test plan docs |
| **Implemented** | Mobile App Scaffolding | Complete Flutter project structure under `mobile/` |
| **Implemented** | Protocol Codec | 20-byte binary decoder (`packet_decoder.dart`) & command encoder (`command_encoder.dart`) |
| **Implemented** | Mock BLE Transport | Deterministic 50 Hz motion data generator (`mock_ble_transport.dart`) |
| **Implemented** | Live Motion Graphs | 6-axis fl_chart with rolling 10s buffer, toggles, & freeze (`live_motion_screen.dart`) |
| **Implemented** | Workout Feature UI | Load entry, mounting guidance, firmware rep counter display (`workout_screen.dart`) |
| **Implemented** | App Routing & Theme | 6 routes (`/device`, `/motion`, `/workout`, `/history`, `/diagnostics`, `/settings`) with dark theme |

## Milestone 2: Offline Storage & Workouts

| Status | Feature / Component | Description |
| :---: | :--- | :--- |
| **Implemented** | Device Repository | Connection state streams, DeviceInfo, SetState, ControlAck dispatch (`device_repository_impl.dart`) |
| **Implemented** | Workout Repository | Draft set creation, wireSetId mapping, atomic state checkpoints, idempotent set upserts (`workout_repository_impl.dart`) |
| **Implemented** | Weight & Rep Corrections | Manual load entry (`kg per dumbbell` / `total load`), user rep corrections retain original `detectedReps` |
| **Implemented** | CSV Motion Exporter | Standard motion headers, formula injection neutralization (`=`, `+`, `-`, `@`), escaping (`csv_exporter.dart`) |

## Milestone 3: Firmware Sketch & Contract Alignment

| Status | Feature / Component | Description |
| :---: | :--- | :--- |
| **Implemented** | Firmware Preservation | Saved original C++ sketch to `firmware/xiao_tracker/xiao_tracker.ino` |
| **Implemented** | Sketch Protocol Adapter | Added `decodeSketchMotion` (16-byte) and `decodeSketchRepCount` (2-byte) to `packet_decoder.dart` |
| **Implemented** | Sketch UUID Definitions | Added sketch Service `6F4C0001...`, Motion `6F4C0002...`, Rep `6F4C0003...` to `ble_uuids.dart` |

## Milestone 4: Real BLE Vertical Slice

| Status | Feature / Component | Description |
| :---: | :--- | :--- |
| **Implemented** | Open-Source BLE Adapter | `universal_ble` (MIT License) integrated behind `BleTransport` interface (`flutter_ble_transport.dart`) |
| **Implemented** | Android & iOS Permissions | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `FINE_LOCATION` in `AndroidManifest.xml` and `NSBluetoothAlwaysUsageDescription` in `Info.plist` |
| **Implemented** | Mode Provider | Dual mode switching via `--dart-define=TRACKER_MODE=real` vs `mock` |
| **Implemented** | Over-the-Air Discovery | Filters & scans for sketch Service `6F4C0001...` and standard v1 Service `9f7c0001...` |
| **Implemented** | Test Suite | 21/21 unit & protocol tests passing (`flutter test`) |
| **Implemented** | Static Analysis | Zero issues found (`flutter analyze`) |
