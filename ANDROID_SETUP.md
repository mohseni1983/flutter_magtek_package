# Android Setup Instructions for Magtek Card Reader Plugin

This document provides detailed setup instructions for Android development and deployment.

## Prerequisites

- Android Studio or VS Code with Flutter extension
- Flutter SDK 3.3.0 or later
- Android SDK with API level 21 or higher
- Android device with USB Host support
- Magtek USB card reader device
- USB OTG cable (if needed for device connection)

## System Requirements

### Android Version Support

- **Minimum SDK**: API 21 (Android 5.0 Lollipop)
- **Target SDK**: API 33 (Android 13) or latest
- **USB Host Support**: Required (most modern Android devices support this)

### Hardware Requirements

- Android device with USB Host capability
- USB OTG (On-The-Go) support
- Sufficient power output for USB devices (some devices may need powered USB hub)

## Development Setup

### 1. Enable USB Host Support

Check if your Android device supports USB Host:

```bash
# Connect to your device via ADB
adb shell

# Check for USB Host support
getprop sys.usb.state
cat /proc/bus/usb/devices
```

### 2. Project Configuration

The plugin automatically configures the necessary permissions and filters. Ensure your app's `android/app/build.gradle` has:

```gradle
android {
    compileSdkVersion 33
    
    defaultConfig {
        minSdkVersion 21  // USB Host API requires API 21+
        targetSdkVersion 33
    }
}
```

### 3. Permissions and Manifest

The plugin automatically adds these permissions to your `AndroidManifest.xml`:

```xml
<!-- USB Host permissions -->
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-feature android:name="android.hardware.usb.host" android:required="false" />
```

### 4. USB Device Filters

USB device filters for Magtek devices are automatically configured:

```xml
<!-- Magtek device filters (vendor ID: 2049 = 0x0801) -->
<usb-device vendor-id="2049" product-id="1" />  <!-- Mini Swipe Reader -->
<usb-device vendor-id="2049" product-id="2" />  <!-- USB Swipe Reader -->
<usb-device vendor-id="2049" product-id="3" />  <!-- eDynamo -->
<usb-device vendor-id="2049" product-id="4" />  <!-- uDynamo -->
<usb-device vendor-id="2049" product-id="16" /> <!-- SureSwipe Reader -->
```

## Hardware Setup

### 1. USB OTG Connection

Most Android devices require a USB OTG adapter to connect USB devices:

1. **USB-C devices**: Use USB-C to USB-A OTG adapter
2. **Micro-USB devices**: Use Micro-USB to USB-A OTG adapter
3. **Direct connection**: Some tablets have full-size USB ports

### 2. Power Considerations

Magtek card readers typically require:
- **5V DC power supply**
- **100-500mA current draw**

If your device cannot provide sufficient power:
- Use a powered USB hub
- Use a USB OTG cable with external power
- Consider a USB-C hub with power delivery

### 3. Device Recognition

To verify device recognition:

```bash
# List USB devices
adb shell lsusb

# Check for Magtek devices (vendor ID 0801)
adb shell "cat /proc/bus/usb/devices | grep -A 5 -B 5 0801"
```

## App Integration

### 1. Basic Implementation

```dart
import 'package:magtek_card_reader/magtek_card_reader.dart';

class AndroidCardReaderExample extends StatefulWidget {
  @override
  _AndroidCardReaderExampleState createState() => _AndroidCardReaderExampleState();
}

class _AndroidCardReaderExampleState extends State<AndroidCardReaderExample> {
  final _cardReader = MagtekCardReader.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeCardReader();
  }
  
  Future<void> _initializeCardReader() async {
    try {
      await _cardReader.initialize();
      
      // Listen for card swipes
      _cardReader.onCardSwipe.listen((cardData) {
        print('Card swiped: ${cardData.maskedAccountNumber}');
      });
      
      // Get available devices
      final devices = await _cardReader.getConnectedDevices();
      if (devices.isNotEmpty) {
        await _cardReader.connectToDevice(devices.first.deviceId);
      }
    } catch (e) {
      print('Failed to initialize: $e');
    }
  }
}
```

### 2. Handling USB Permissions

Android requires explicit user permission for USB device access:

```dart
Future<void> _connectToDevice(String deviceId) async {
  try {
    // This will trigger permission request if needed
    final success = await _cardReader.connectToDevice(deviceId);
    
    if (success) {
      print('Connected successfully');
    } else {
      print('Connection failed - check permissions');
    }
  } catch (e) {
    print('Connection error: $e');
  }
}
```

### 3. USB Device Detection

Handle USB device attachment events:

```dart
@override
void initState() {
  super.initState();
  
  // Listen for device connections
  _cardReader.onDeviceConnected.listen((deviceInfo) {
    print('Device connected: ${deviceInfo.deviceName}');
    // Auto-connect or show user prompt
  });
}
```

## Testing and Debugging

### 1. USB Device Debugging

Enable USB debugging and check device recognition:

```bash
# Enable USB debugging
adb shell settings put global development_settings_enabled 1
adb shell settings put global usb_debugging_enabled 1

# Monitor USB events
adb shell "logcat | grep -i usb"

# Check connected devices
adb shell service call usb 1
```

### 2. Plugin Debugging

Enable detailed logging in your app:

```dart
import 'dart:developer' as developer;

// Add logging to track plugin behavior
_cardReader.onError.listen((error) {
  developer.log('Card reader error: ${error.message}', name: 'MagtekPlugin');
});
```

### 3. Native Debugging

For native Android debugging, check logcat output:

```bash
# Filter Magtek plugin logs
adb logcat | grep MagtekCardReaderPlugin

# Monitor USB manager logs
adb logcat | grep MagtekUSBManager
```

## Common Issues and Solutions

### 1. Device Not Detected

**Symptoms**: No devices appear in `getConnectedDevices()`

**Solutions**:
- Verify USB OTG cable functionality
- Check device power supply
- Confirm USB Host support on device
- Try different USB port/cable

**Debugging**:
```bash
# Check if device appears in system
adb shell lsusb
adb shell "cat /sys/kernel/debug/usb/devices"
```

### 2. Permission Denied

**Symptoms**: `connectToDevice()` returns false

**Solutions**:
- Ensure USB permissions are requested
- Check AndroidManifest.xml configuration
- Verify USB device filters are correct
- Try manually granting USB permissions

**Debugging**:
```bash
# Check app permissions
adb shell pm list permissions com.your.package
```

### 3. No Data from Card Swipes

**Symptoms**: Device connects but no card swipe events

**Solutions**:
- Verify card reader is functioning
- Check USB data connection (not just power)
- Ensure proper USB endpoint communication
- Try different card types

**Debugging**:
```kotlin
// Add logging in AndroidUsbDeviceManager.kt
Log.d(TAG, "Endpoint: ${endpoint.address}, Type: ${endpoint.type}")
Log.d(TAG, "Bytes read: $bytesRead, Data: ${buffer.contentToString()}")
```

### 4. App Crashes on Device Connection

**Symptoms**: App crashes when USB device is connected

**Solutions**:
- Check for proper error handling
- Verify USB permissions are handled correctly
- Ensure proper thread safety in callbacks
- Check for memory leaks in device management

### 5. Intermittent Connection Issues

**Symptoms**: Device connects/disconnects randomly

**Solutions**:
- Check USB cable quality
- Verify power stability
- Implement reconnection logic
- Handle device detachment gracefully

## Performance Optimization

### 1. Background Processing

Handle USB operations on background threads:

```kotlin
// Already implemented in AndroidUsbDeviceManager
monitoringScope.launch {
    while (isMonitoring && isActive) {
        if (isConnected()) {
            readFromDevice()
        }
        delay(50) // Adjust polling interval as needed
    }
}
```

### 2. Memory Management

Properly clean up resources:

```dart
@override
void dispose() {
  _cardReader.dispose();
  super.dispose();
}
```

### 3. Battery Optimization

Minimize background USB polling when not needed:

```dart
void pauseMonitoring() {
  // Stop monitoring when app is backgrounded
  _cardReader.stopMonitoring();
}

void resumeMonitoring() {
  // Resume monitoring when app is foregrounded
  _cardReader.startMonitoring();
}
```

## Production Deployment

### 1. Permissions and Security

- Request USB permissions only when needed
- Handle permission denials gracefully
- Implement proper error handling for all USB operations
- Consider adding user guidance for USB setup

### 2. Device Compatibility

Test on various Android devices:
- Different Android versions (API 21+)
- Various USB Host implementations
- Different power management behaviors
- Tablet vs phone form factors

### 3. App Store Considerations

- Declare USB Host feature requirement if mandatory
- Provide clear setup instructions for users
- Include device compatibility information
- Handle devices without USB Host support gracefully

### 4. User Experience

- Provide clear USB setup instructions
- Show device connection status
- Handle permission requests smoothly
- Implement retry mechanisms for connection failures

## Troubleshooting Checklist

### Device Setup
- [ ] Android device supports USB Host
- [ ] USB OTG cable is functional
- [ ] Magtek device is powered properly
- [ ] Device appears in system USB device list

### App Configuration
- [ ] Minimum SDK version is 21 or higher
- [ ] USB permissions are declared in manifest
- [ ] USB device filters are correctly configured
- [ ] Plugin is properly initialized

### Runtime Issues
- [ ] USB permissions are granted by user
- [ ] Device connection returns true
- [ ] Event listeners are properly set up
- [ ] Error handling is implemented

### Debugging Tools
- [ ] ADB is connected and functional
- [ ] USB debugging is enabled
- [ ] Logcat shows relevant plugin logs
- [ ] Native debugging tools are available

## Support and Resources

### Documentation
- [Android USB Host API Guide](https://developer.android.com/guide/topics/connectivity/usb/host)
- [Flutter Plugin Development](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [USB OTG Compatibility](https://en.wikipedia.org/wiki/USB_On-The-Go)

### Common Tools
- **USB Device Info** apps for testing device recognition
- **OTG checker** apps to verify USB Host support
- **Terminal emulator** for command-line debugging
- **Android Studio** for native code debugging

### Getting Help

When seeking support, include:
1. Android device model and OS version
2. Magtek device model and firmware version
3. Complete error logs from logcat
4. USB device enumeration output
5. App manifest configuration

This comprehensive guide should help you successfully implement and deploy the Magtek Card Reader plugin on Android devices.
