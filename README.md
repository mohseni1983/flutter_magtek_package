# Magtek Card Reader Plugin

A Flutter plugin for communicating with Magtek 3-track credit card readers via USB on Linux and Raspberry Pi platforms.

## Features

- ✅ USB HID communication with Magtek card readers
- ✅ 3-track magnetic stripe data parsing
- ✅ Real-time card swipe detection
- ✅ Device discovery and connection management
- ✅ Card brand identification (Visa, Mastercard, Amex, etc.)
- ✅ Luhn algorithm validation
- ✅ Comprehensive error handling
- ✅ Linux and Raspberry Pi support

## Supported Devices

This plugin supports the following Magtek card readers:

- Magtek Mini Swipe Reader (Product ID: 0x0001)
- Magtek USB Swipe Reader (Product ID: 0x0002)
- Magtek eDynamo (Product ID: 0x0003)
- Magtek uDynamo (Product ID: 0x0004)
- Magtek SureSwipe Reader (Product ID: 0x0010)

All devices use vendor ID: 0x0801

## Platform Support

| Platform    | Support |
|-------------|---------|
| Linux       | ✅      |
| Windows     | ✅      |
| Raspberry Pi| ✅      |
| macOS       | ❌      |
| Android     | ❌      |
| iOS         | ❌      |

## Installation

### 1. Add Dependency

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  magtek_card_reader: ^1.0.0
```

### 2. Install System Dependencies

#### Windows:
```cmd
# Install Visual Studio 2019 or later with C++ development tools
# Install vcpkg (recommended) or use Windows HID APIs directly
vcpkg install hidapi:x64-windows

# Enable Flutter desktop support
flutter config --enable-windows-desktop
```

#### Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install libusb-1.0-0-dev libhidapi-dev
```

#### Raspberry Pi OS:
```bash
sudo apt-get update
sudo apt-get install libusb-1.0-0-dev libhidapi-dev
```

#### Fedora/RHEL/CentOS:
```bash
sudo dnf install libusb1-devel hidapi-devel
# or for older versions:
sudo yum install libusb1-devel hidapi-devel
```

### 3. Set Up Device Permissions

#### Windows:
Windows 10+ automatically installs HID drivers for Magtek devices. No additional configuration needed.

#### Linux:
Create a udev rule to allow access to Magtek devices:

```bash
sudo nano /etc/udev/rules.d/99-magtek.rules
```

Add the following content:

```bash
# Magtek USB Card Readers
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0001", MODE="0666", GROUP="plugdev"
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0002", MODE="0666", GROUP="plugdev"
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0003", MODE="0666", GROUP="plugdev"
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0004", MODE="0666", GROUP="plugdev"
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0010", MODE="0666", GROUP="plugdev"
```

Reload udev rules and add your user to the plugdev group:

```bash
sudo udevadm control --reload-rules
sudo usermod -aG plugdev $USER
```

**Important:** Log out and log back in for the group changes to take effect.

### 4. Install Flutter Dependencies

```bash
flutter pub get
```

For detailed platform-specific setup instructions, see:
- [Windows Setup Guide](WINDOWS_SETUP.md)
- [Linux Setup Guide](SETUP.md)

## Usage

### Basic Example

```dart
import 'package:magtek_card_reader/magtek_card_reader.dart';

class CardReaderExample extends StatefulWidget {
  @override
  _CardReaderExampleState createState() => _CardReaderExampleState();
}

class _CardReaderExampleState extends State<CardReaderExample> {
  final _cardReader = MagtekCardReader.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeCardReader();
  }
  
  Future<void> _initializeCardReader() async {
    try {
      // Initialize the card reader
      await _cardReader.initialize();
      
      // Listen for card swipes
      _cardReader.onCardSwipe.listen((cardData) {
        print('Card swiped: ${cardData.maskedAccountNumber}');
        print('Card brand: ${cardData.cardBrand}');
        print('Valid: ${cardData.isValidPaymentCard}');
      });
      
      // Listen for device connections
      _cardReader.onDeviceConnected.listen((deviceInfo) {
        print('Device connected: ${deviceInfo.deviceName}');
      });
      
      // Listen for errors
      _cardReader.onError.listen((error) {
        print('Error: ${error.message}');
      });
      
    } catch (e) {
      print('Failed to initialize: $e');
    }
  }
  
  @override
  void dispose() {
    _cardReader.dispose();
    super.dispose();
  }
}
```

### Device Management

```dart
// Get list of connected devices
List<DeviceInfo> devices = await _cardReader.getConnectedDevices();

// Connect to a specific device
bool success = await _cardReader.connectToDevice(deviceId);

// Check connection status
bool isConnected = await _cardReader.isConnected();

// Disconnect
await _cardReader.disconnect();
```

### Card Data Processing

```dart
_cardReader.onCardSwipe.listen((CardData cardData) {
  // Basic card information
  print('Account Number: ${cardData.maskedAccountNumber}');
  print('Cardholder Name: ${cardData.cardholderName}');
  print('Expiration Date: ${cardData.expirationDate}');
  print('Card Brand: ${cardData.cardBrand}');
  
  // Validation
  print('Valid Payment Card: ${cardData.isValidPaymentCard}');
  
  // Track information
  print('Decoded Tracks: ${cardData.decodedTracks.length}');
  
  // Raw data access
  if (cardData.track1 != null) {
    print('Track 1 Raw: ${cardData.track1!.rawData}');
  }
  if (cardData.track2 != null) {
    print('Track 2 Raw: ${cardData.track2!.rawData}');
  }
});
```

## API Reference

### MagtekCardReader

The main class for interacting with Magtek card readers.

#### Properties

- `Stream<CardData> onCardSwipe` - Stream of card swipe events
- `Stream<DeviceInfo> onDeviceConnected` - Stream of device connection events
- `Stream<MagtekException> onError` - Stream of error events

#### Methods

- `Future<void> initialize()` - Initialize the card reader
- `Future<void> dispose()` - Dispose of resources
- `Future<List<DeviceInfo>> getConnectedDevices()` - Get connected devices
- `Future<bool> connectToDevice(String deviceId)` - Connect to a device
- `Future<void> disconnect()` - Disconnect from current device
- `Future<bool> isConnected()` - Check connection status
- `Future<String?> getPlatformVersion()` - Get platform version

### CardData

Represents complete card data from all tracks.

#### Properties

- `TrackData? track1` - Track 1 data
- `TrackData? track2` - Track 2 data  
- `TrackData? track3` - Track 3 data
- `DateTime timestamp` - Swipe timestamp
- `bool hasValidData` - Whether any track was decoded
- `String? deviceId` - Device that read the card
- `String? primaryAccountNumber` - PAN from tracks
- `String? cardholderName` - Name (Track 1 only)
- `String? expirationDate` - Expiration date
- `String? cardBrand` - Card brand (Visa, Mastercard, etc.)
- `String? maskedAccountNumber` - Masked PAN for display
- `bool isValidPaymentCard` - Luhn algorithm validation
- `List<TrackData> decodedTracks` - Successfully decoded tracks
- `List<TrackData> failedTracks` - Failed tracks

### TrackData

Represents data from a single track.

#### Properties

- `int trackNumber` - Track number (1, 2, or 3)
- `String? rawData` - Raw track data
- `bool isDecoded` - Whether successfully decoded
- `String? errorMessage` - Error message if failed
- `String? accountNumber` - Account number (Track 1)
- `String? cardholderName` - Cardholder name (Track 1)
- `String? expirationDate` - Expiration date (Tracks 1&2)
- `String? serviceCode` - Service code (Tracks 1&2)
- `String? discretionaryData` - Discretionary data

### DeviceInfo

Information about a Magtek device.

#### Properties

- `String deviceId` - Unique device identifier
- `String deviceName` - Device name/model
- `int vendorId` - USB vendor ID
- `int productId` - USB product ID
- `String? serialNumber` - Serial number
- `String? firmwareVersion` - Firmware version
- `bool isConnected` - Connection status
- `String? devicePath` - Device path
- `String deviceType` - Device type description
- `String displayName` - User-friendly name

## Error Handling

The plugin provides comprehensive error handling through various exception types:

```dart
_cardReader.onError.listen((MagtekException error) {
  switch (error.runtimeType) {
    case DeviceInitializationException:
      print('Initialization failed: ${error.message}');
      break;
    case DeviceConnectionException:
      print('Connection failed: ${error.message}');
      break;
    case UsbCommunicationException:
      print('USB error: ${error.message}');
      break;
    case CardDataParsingException:
      print('Parsing error: ${error.message}');
      break;
    case DevicePermissionException:
      print('Permission error: ${error.message}');
      break;
    default:
      print('General error: ${error.message}');
  }
});
```

## Troubleshooting

### Device Not Found

1. **Check USB connection**: Ensure the device is properly connected
2. **Check permissions**: Verify udev rules are installed and user is in plugdev group
3. **Check dependencies**: Ensure libusb and hidapi are installed
4. **Restart udev**: `sudo udevadm control --reload-rules`

### Permission Denied

1. **Add user to plugdev group**: `sudo usermod -aG plugdev $USER`
2. **Log out and back in** for group changes to take effect
3. **Check udev rules**: Ensure the udev rule file exists and has correct content
4. **Check device permissions**: `ls -l /dev/hidraw*`

### Card Reading Issues

1. **Check device connection**: Ensure device is connected and recognized
2. **Clean card and reader**: Dirt can interfere with reading
3. **Swipe speed**: Try different swipe speeds (not too fast or slow)
4. **Card condition**: Ensure magnetic stripe is not damaged

### Compilation Issues

1. **Install dependencies**: Make sure libusb and hidapi development packages are installed
2. **Update CMake**: Ensure CMake 3.10 or later is installed
3. **Clean build**: `flutter clean && flutter pub get`

## Security Considerations

⚠️ **Important Security Notes:**

1. **PCI Compliance**: This plugin reads unencrypted magnetic stripe data. Ensure your application complies with PCI DSS requirements.

2. **Data Storage**: Never store unencrypted card data. Process and transmit data securely.

3. **Network Security**: Use secure connections (HTTPS/TLS) when transmitting card data.

4. **Memory Management**: Card data is held in memory temporarily. Ensure sensitive data is cleared appropriately.

5. **Access Control**: Restrict access to card reader functionality to authorized users only.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Search existing GitHub issues
3. Create a new issue with detailed information about your problem

## Changelog

### 1.0.0
- Initial release
- USB HID communication support
- 3-track magnetic stripe parsing
- Linux and Raspberry Pi support
- Device discovery and management
- Comprehensive error handling
- Example application