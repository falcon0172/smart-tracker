# iOS Setup Guide — Smart Tracker Companion App

## Requirements
- **Hardware**: Physical iPhone (iOS 15+) for physical BLE acceptance testing. (iOS Simulator does not support Bluetooth Low Energy hardware peripherals).
- **Host**: macOS machine with Xcode 15+ installed.

## Info.plist Configuration
Ensure `ios/Runner/Info.plist` contains the mandatory Bluetooth permission description:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Smart Tracker requires Bluetooth access to connect to your detachable XIAO workout tracker and count reps in real time.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Smart Tracker uses Bluetooth Peripheral access to communicate with the XIAO sensor board.</string>
```

## Building on iOS
```bash
cd mobile
flutter build ios --release
```
