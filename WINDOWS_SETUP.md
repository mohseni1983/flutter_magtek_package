# Windows Setup Instructions for Magtek Card Reader Plugin

This document provides detailed setup instructions for Windows development and deployment.

## Prerequisites

- Windows 10 or later (Windows 11 recommended)
- Visual Studio 2019 or later with C++ development tools
- Flutter 3.3.0 or later
- Magtek USB card reader device
- Administrative privileges for driver installation

## System Requirements

### Visual Studio Components

Ensure you have the following Visual Studio components installed:

1. **Desktop development with C++** workload
2. **CMake tools for C++**
3. **Windows 10/11 SDK** (latest version)
4. **MSVC v143 compiler toolset**
5. **Git for Windows** (if not already installed)

### Flutter Desktop Support

Enable Flutter desktop support if not already enabled:

```cmd
flutter config --enable-windows-desktop
```

## HIDAPI Installation

### Option 1: Using vcpkg (Recommended)

1. **Install vcpkg** (if not already installed):
   ```cmd
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   .\vcpkg integrate install
   ```

2. **Install HIDAPI**:
   ```cmd
   # For x64 architecture
   .\vcpkg install hidapi:x64-windows
   
   # For x86 architecture (if needed)
   .\vcpkg install hidapi:x86-windows
   ```

3. **Set Environment Variable** (if using CMake manually):
   ```cmd
   set CMAKE_TOOLCHAIN_FILE=C:\path\to\vcpkg\scripts\buildsystems\vcpkg.cmake
   ```

### Option 2: Manual Installation

If you prefer not to use vcpkg, the plugin will fallback to using Windows HID APIs directly (setupapi.dll, hid.dll).

## Driver Installation

### Automatic Driver Installation

Windows 10 and later should automatically install the necessary HID drivers for Magtek devices. Simply connect your device and Windows should recognize it.

### Manual Driver Installation

If automatic installation fails:

1. **Download Magtek Drivers** from the official Magtek website
2. **Connect your device** and open Device Manager
3. **Locate the unrecognized device** (usually under "Other devices")
4. **Right-click** and select "Update driver"
5. **Browse for drivers** and select the downloaded Magtek driver folder

### Verify Driver Installation

1. Open **Device Manager** (devmgmt.msc)
2. Look under **Human Interface Devices**
3. You should see your Magtek device listed (e.g., "HID-compliant device")
4. Check **Device Properties** to confirm Vendor ID is 0801

## Development Setup

### 1. Clone and Configure Project

```cmd
# Navigate to your development directory
cd C:\dev

# Clone or copy the magtek_card_reader plugin
# Then navigate to the plugin directory
cd magtek_card_reader
```

### 2. Install Flutter Dependencies

```cmd
flutter pub get
```

### 3. Build and Test

```cmd
# Build the Windows version
flutter build windows

# Run the example app
cd example
flutter run -d windows
```

## Visual Studio Configuration

### 1. Open in Visual Studio

You can open the Windows project in Visual Studio for debugging:

```cmd
# Navigate to the example Windows build directory
cd example\build\windows

# Open the solution file
start .\magtek_card_reader_example.sln
```

### 2. Debug Configuration

1. Set the startup project to `magtek_card_reader_example`
2. Select the appropriate configuration (Debug/Release)
3. Choose the correct platform (x64 recommended)
4. Set breakpoints as needed
5. Press F5 to start debugging

## Troubleshooting

### Device Not Detected

1. **Check Device Manager**:
   - Ensure the device appears under "Human Interface Devices"
   - Verify there are no error indicators (yellow triangles)

2. **Driver Issues**:
   ```cmd
   # Check for driver problems
   pnputil /enum-devices /problem
   ```

3. **USB Port Issues**:
   - Try different USB ports
   - Use a powered USB hub if needed
   - Avoid USB 3.0 ports if experiencing issues

### Build Issues

1. **CMake Errors**:
   ```cmd
   # Clear CMake cache
   flutter clean
   rm -rf build/
   flutter pub get
   flutter build windows
   ```

2. **HIDAPI Not Found**:
   - Ensure vcpkg is properly installed and integrated
   - Check that CMAKE_TOOLCHAIN_FILE is set correctly
   - Verify HIDAPI was installed for the correct architecture

3. **Visual Studio Errors**:
   - Ensure all required Visual Studio components are installed
   - Try building from a "Developer Command Prompt"
   - Check that Windows SDK version matches your system

### Runtime Issues

1. **Access Denied**:
   - Run as Administrator if needed
   - Check that the device is not being used by another application

2. **DLL Loading Errors**:
   ```cmd
   # Check dependencies
   dumpbin /dependents magtek_card_reader_plugin.dll
   ```

3. **Permission Issues**:
   - Ensure the application has appropriate permissions
   - Check Windows Defender or antivirus settings

## Performance Optimization

### 1. Release Build

Always use Release builds for production:

```cmd
flutter build windows --release
```

### 2. Compiler Optimizations

The CMakeLists.txt includes optimizations, but you can add more:

```cmake
# Add to CMakeLists.txt for additional optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(${PLUGIN_NAME} PRIVATE /O2 /GL)
    target_link_options(${PLUGIN_NAME} PRIVATE /LTCG)
endif()
```

## Deployment

### 1. Bundling Dependencies

```cmd
# Build with bundled dependencies
flutter build windows --release

# The output will be in build\windows\x64\runner\Release\
```

### 2. Creating an Installer

Consider using tools like:
- **Inno Setup** for simple installers
- **WiX Toolset** for Windows Installer packages
- **NSIS** for lightweight installers

### 3. Distribution Considerations

- Include any required Visual C++ redistributables
- Test on clean Windows installations
- Consider code signing for production applications
- Include appropriate driver installation instructions

## Security Considerations

### 1. Code Signing

For production deployment:

```cmd
# Sign the executable and DLLs
signtool sign /f certificate.p12 /p password /t http://timestamp.digicert.com magtek_card_reader_example.exe
```

### 2. Windows Defender

- Add exclusions for development directories if needed
- Test with real-time protection enabled
- Consider SmartScreen implications

### 3. User Account Control (UAC)

- Design the application to work without admin privileges
- Use manifests to declare required privileges
- Consider using a Windows service for device access if needed

## Advanced Configuration

### 1. Custom Device Filters

You can modify the device detection in `windows_usb_device_manager.cpp`:

```cpp
// Add custom vendor/product IDs
const std::vector<unsigned short> CUSTOM_PRODUCT_IDS = {
    0x0001, // Your custom device
    // Add more as needed
};
```

### 2. Registry Configuration

For enterprise deployment, consider registry settings:

```reg
[HKEY_LOCAL_MACHINE\SOFTWARE\YourCompany\MagtekCardReader]
"DeviceTimeout"=dword:00001388
"AutoConnect"=dword:00000001
```

### 3. Service Integration

For system-wide access, consider implementing a Windows service that manages device access and communicates with client applications.

## Testing

### 1. Unit Testing

```cmd
# Run C++ unit tests
cd build\windows\x64\runner\Release
.\magtek_card_reader_test.exe
```

### 2. Integration Testing

```cmd
# Run Flutter integration tests
flutter test integration_test\
```

### 3. Device Testing

- Test with multiple device models
- Test device hotplug scenarios
- Test with multiple applications accessing devices
- Test after system resume from sleep/hibernation

## Support

### Common Issues

1. **"Device not found" errors** - Check driver installation and device connectivity
2. **"Access denied" errors** - Verify permissions and check for conflicting applications
3. **Build failures** - Ensure all dependencies are properly installed
4. **Runtime crashes** - Check Visual Studio debugger output and Windows Event Log

### Getting Help

1. Check the main README.md troubleshooting section
2. Review Windows Event Viewer for system errors
3. Use Visual Studio debugger for detailed error information
4. Create GitHub issues with complete error logs and system information

### System Information for Bug Reports

When reporting issues, include:

```cmd
# Windows version
ver

# Flutter information
flutter doctor -v

# Visual Studio information
where devenv
devenv /? | head -5

# Device information from Device Manager
```

This comprehensive Windows setup should help you successfully build, deploy, and debug the Magtek Card Reader plugin on Windows platforms.
