# Windows Setup Guide — Smart Tracker Companion App

## Environment Requirements
- **OS**: Windows 10/11 64-bit
- **Flutter SDK**: `3.47.4` (Channel stable) located at `C:\flutter`
- **JDK**: OpenJDK `17` located at `C:\Android\jdk-17`
- **Android SDK**: Version `36.0.0` located at `C:\Android\Sdk`

## Running in Mock Mode (Default)
To run the companion application with simulated 50 Hz motion data and full offline features:

```powershell
$env:JAVA_HOME = "C:\Android\jdk-17"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:PATH = "C:\flutter\bin;C:\Android\jdk-17\bin;C:\Android\Sdk\platform-tools;" + $env:PATH

cd mobile
flutter run -d chrome --dart-define=TRACKER_MODE=mock
```

## Running Unit & Protocol Tests

```powershell
cd mobile
flutter test
```
