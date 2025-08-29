# Setup Instructions for Magtek Card Reader Plugin

This document provides detailed setup instructions for different Linux distributions and Raspberry Pi.

## Prerequisites

- Flutter 3.3.0 or later
- Linux-based operating system (Ubuntu, Debian, Fedora, etc.) or Raspberry Pi OS
- Magtek USB card reader device
- Administrative privileges for system configuration

## System Dependencies

### Ubuntu/Debian/Raspberry Pi OS

```bash
# Update package list
sudo apt-get update

# Install required development packages
sudo apt-get install -y \
  libusb-1.0-0-dev \
  libhidapi-dev \
  build-essential \
  cmake \
  pkg-config

# For Raspberry Pi, you might also need:
sudo apt-get install -y libudev-dev
```

### Fedora/RHEL/CentOS 8+

```bash
# Install required packages
sudo dnf install -y \
  libusb1-devel \
  hidapi-devel \
  gcc-c++ \
  cmake \
  pkgconfig

# For older versions (CentOS 7, RHEL 7):
# sudo yum install libusb1-devel hidapi-devel gcc-c++ cmake pkgconfig
```

### Arch Linux

```bash
# Install required packages
sudo pacman -S \
  libusb \
  hidapi \
  base-devel \
  cmake \
  pkgconf
```

### openSUSE

```bash
# Install required packages
sudo zypper install \
  libusb-1_0-devel \
  libhidapi-devel \
  gcc-c++ \
  cmake \
  pkg-config
```

## USB Permissions Setup

### 1. Create udev Rules

Create a udev rule file to grant access to Magtek devices:

```bash
sudo nano /etc/udev/rules.d/99-magtek.rules
```

Add the following content to the file:

```bash
# Magtek USB Card Readers - Grant access to plugdev group
# Vendor ID: 0801 (Magtek)

# Mini Swipe Reader
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0001", MODE="0666", GROUP="plugdev", TAG+="uaccess"

# USB Swipe Reader
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0002", MODE="0666", GROUP="plugdev", TAG+="uaccess"

# eDynamo
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0003", MODE="0666", GROUP="plugdev", TAG+="uaccess"

# uDynamo
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0004", MODE="0666", GROUP="plugdev", TAG+="uaccess"

# SureSwipe Reader
ATTRS{idVendor}=="0801", ATTRS{idProduct}=="0010", MODE="0666", GROUP="plugdev", TAG+="uaccess"

# Generic rule for other Magtek devices
ATTRS{idVendor}=="0801", MODE="0666", GROUP="plugdev", TAG+="uaccess"
```

### 2. Create plugdev Group (if it doesn't exist)

```bash
# Check if plugdev group exists
getent group plugdev

# If the command above returns nothing, create the group:
sudo groupadd plugdev
```

### 3. Add User to plugdev Group

```bash
# Add current user to plugdev group
sudo usermod -aG plugdev $USER

# Verify the user was added
groups $USER
```

### 4. Reload udev Rules

```bash
# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Restart udev service (optional, but recommended)
sudo systemctl restart udev
```

### 5. Log Out and Back In

**Important:** Log out and log back in (or restart your system) for the group changes to take effect.

## Verification

### 1. Check USB Device Recognition

Connect your Magtek device and verify it's recognized:

```bash
# List USB devices
lsusb | grep -i magtek

# Should show something like:
# Bus 001 Device 004: ID 0801:0001 Mag-Tek Mini Swipe Reader
```

### 2. Check Device Permissions

```bash
# Find the device in /dev
ls -la /dev/hidraw*

# Check specific device permissions (replace X with actual number)
ls -la /dev/hidrawX

# Should show something like:
# crw-rw-rw- 1 root plugdev 247, 0 Nov 15 10:30 /dev/hidraw0
```

### 3. Test Group Membership

```bash
# Check current groups
groups

# Should include 'plugdev' in the output
```

## Flutter Project Setup

### 1. Add Dependency

In your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  magtek_card_reader: ^1.0.0
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the Example

```bash
# Navigate to the plugin directory
cd path/to/magtek_card_reader/example

# Run the example app
flutter run -d linux
```

## Testing the Installation

### 1. Basic Device Detection Test

Create a simple test to verify device detection:

```dart
import 'package:magtek_card_reader/magtek_card_reader.dart';

void testDeviceDetection() async {
  final cardReader = MagtekCardReader.instance;
  
  try {
    await cardReader.initialize();
    print('Card reader initialized successfully');
    
    final devices = await cardReader.getConnectedDevices();
    print('Found ${devices.length} Magtek devices:');
    
    for (final device in devices) {
      print('- ${device.displayName} (${device.deviceId})');
    }
    
    if (devices.isNotEmpty) {
      print('Attempting to connect to first device...');
      final success = await cardReader.connectToDevice(devices.first.deviceId);
      print('Connection ${success ? "successful" : "failed"}');
      
      if (success) {
        print('Device is connected and ready for card swipes');
      }
    }
    
  } catch (e) {
    print('Error: $e');
  } finally {
    await cardReader.dispose();
  }
}
```

### 2. Card Swipe Test

If you have a test card (not a real credit card), you can test card reading:

```dart
void testCardReading() async {
  final cardReader = MagtekCardReader.instance;
  
  await cardReader.initialize();
  
  cardReader.onCardSwipe.listen((cardData) {
    print('Card swiped!');
    print('Tracks decoded: ${cardData.decodedTracks.length}');
    print('Valid payment card: ${cardData.isValidPaymentCard}');
    if (cardData.track1 != null) {
      print('Track 1 length: ${cardData.track1!.rawData?.length ?? 0}');
    }
    if (cardData.track2 != null) {
      print('Track 2 length: ${cardData.track2!.rawData?.length ?? 0}');
    }
  });
  
  final devices = await cardReader.getConnectedDevices();
  if (devices.isNotEmpty) {
    await cardReader.connectToDevice(devices.first.deviceId);
    print('Swipe a test card now...');
  }
}
```

## Troubleshooting

### Permission Issues

If you get permission denied errors:

1. **Verify group membership:**
   ```bash
   groups $USER | grep plugdev
   ```

2. **Check udev rule syntax:**
   ```bash
   sudo udevadm test $(udevadm info -q path -n /dev/hidraw0) 2>&1 | grep magtek
   ```

3. **Reload and re-trigger udev:**
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger --attr-match=subsystem=hidraw
   ```

### Device Not Found

1. **Check USB connection:**
   ```bash
   dmesg | tail -n 20
   lsusb | grep 0801
   ```

2. **Check hidraw devices:**
   ```bash
   ls -la /sys/class/hidraw/
   cat /sys/class/hidraw/hidraw*/device/uevent
   ```

### Compilation Issues

1. **Missing development packages:**
   ```bash
   pkg-config --exists libusb-1.0 && echo "libusb-1.0 found" || echo "libusb-1.0 missing"
   pkg-config --exists hidapi && echo "hidapi found" || echo "hidapi missing"
   ```

2. **CMake issues:**
   ```bash
   cmake --version  # Should be 3.10 or later
   ```

3. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter build linux
   ```

### Raspberry Pi Specific Issues

1. **Enable USB OTG (if needed):**
   ```bash
   echo 'dtoverlay=dwc2' | sudo tee -a /boot/config.txt
   echo 'modules-load=dwc2' | sudo tee -a /boot/cmdline.txt
   ```

2. **Increase USB power (if needed):**
   ```bash
   echo 'max_usb_current=1' | sudo tee -a /boot/config.txt
   ```

3. **Install additional ARM dependencies:**
   ```bash
   sudo apt-get install -y gcc-arm-linux-gnueabihf
   ```

## Security Notes

1. **File Permissions:** The udev rules grant broad access (0666). For production, consider more restrictive permissions.

2. **Group Membership:** Only add trusted users to the plugdev group.

3. **Device Access:** Consider implementing application-level access controls for sensitive environments.

## Production Deployment

For production deployments:

1. **Create application-specific udev rules** with more restrictive permissions
2. **Use systemd service** to manage the application
3. **Implement logging** for security auditing
4. **Consider device whitelisting** to only allow specific serial numbers
5. **Regular security updates** for all system dependencies

## Support

If you encounter issues during setup:

1. Check the main README.md troubleshooting section
2. Verify all steps in this setup guide
3. Create a GitHub issue with:
   - Your Linux distribution and version
   - Complete error messages
   - Output of relevant diagnostic commands
   - Hardware information about your Magtek device
