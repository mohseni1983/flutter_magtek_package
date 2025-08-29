# Changelog

All notable changes to the Magtek Card Reader plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2024-01-15

### Added
- Web platform support with WebUSB API implementation
- Browser-based USB device access (Chrome, Edge, Opera)
- HTTPS security requirement for production deployment
- Real-time card swipe detection in web browsers
- Native browser device selection dialogs
- Web-specific setup documentation and deployment guide
- Cross-platform support (Web, Android, Linux, Windows, Raspberry Pi)

### Technical Features
- JavaScript/Dart interop for WebUSB communication
- Timer-based device monitoring for web performance
- Proper error handling for unsupported browsers
- Security headers and permissions policy configuration

## [1.2.0] - 2024-01-15

### Added
- Android platform support with Kotlin implementation
- USB Host API integration for Android devices
- Automatic USB permission handling
- USB device filters for Magtek devices
- Coroutine-based background monitoring
- Android-specific setup documentation
- Cross-platform support (Android, Linux, Windows, Raspberry Pi)

## [1.1.0] - 2024-01-15

### Added
- Windows platform support with native C++ implementation
- HIDAPI integration for Windows with vcpkg support
- Fallback to native Windows HID APIs when HIDAPI is not available
- Visual Studio project files and CMake configuration for Windows
- Windows-specific setup documentation
- Cross-platform development support (Linux, Windows, Raspberry Pi)

## [1.0.0] - 2024-01-15

### Added
- Initial release of Magtek Card Reader plugin
- USB HID communication support for Magtek 3-track card readers
- Support for Linux and Raspberry Pi platforms
- Device discovery and enumeration
- Real-time card swipe detection via event streams
- Comprehensive magnetic stripe data parsing for all 3 tracks
- Card brand identification (Visa, Mastercard, American Express, Discover, JCB)
- Luhn algorithm validation for payment cards
- Support for the following Magtek devices:
  - Mini Swipe Reader (Product ID: 0x0001)
  - USB Swipe Reader (Product ID: 0x0002)
  - eDynamo (Product ID: 0x0003)
  - uDynamo (Product ID: 0x0004)
  - SureSwipe Reader (Product ID: 0x0010)
- Device connection management with automatic reconnection
- Comprehensive error handling with specific exception types:
  - DeviceInitializationException
  - DeviceConnectionException
  - UsbCommunicationException
  - CardDataParsingException
  - DevicePermissionException
  - DeviceNotFoundException
  - DeviceBusyException
  - TimeoutException
  - PlatformNotSupportedException
- Track data parsing with detailed field extraction:
  - Track 1: Account number, cardholder name, expiration date, service code
  - Track 2: Primary account number, expiration date, service code
  - Track 3: Additional discretionary data
- Raw data access for debugging and advanced processing
- Stream-based architecture for real-time event handling
- Singleton pattern for easy global access
- JSON serialization support for all data models
- Comprehensive example application demonstrating all features
- Professional UI with card swipe history and device management
- Detailed setup and installation documentation
- Automated installation script for system dependencies
- udev rules for USB device permissions
- Cross-platform build system using CMake
- Native C++ implementation with libusb and hidapi
- Memory-safe device management with RAII patterns
- Multi-threaded card monitoring with proper synchronization
- Flutter method channels and event channels integration
- Platform-specific error handling and reporting
- Extensive inline documentation and code comments

### Features
- **Device Management**
  - Automatic device discovery
  - Connect/disconnect functionality
  - Device status monitoring
  - Multi-device support

- **Card Reading**
  - 3-track magnetic stripe reading
  - Real-time swipe detection
  - Automatic track parsing
  - Data validation

- **Security**
  - Secure memory handling
  - PCI DSS compliance guidelines
  - Access control recommendations
  - Data masking for display

- **Developer Experience**
  - Comprehensive API documentation
  - Example application
  - Setup automation
  - Troubleshooting guides

### Technical Implementation
- **Native Layer**
  - C++ implementation with modern C++14 standards
  - libusb 1.0 for USB communication
  - hidapi for HID device interaction
  - CMake build system
  - Memory-safe resource management
  - Thread-safe device operations

- **Flutter Layer**
  - Dart 3.x compatibility
  - Method channels for synchronous operations
  - Event channels for asynchronous data streams
  - Singleton pattern for global access
  - Stream-based reactive architecture
  - Comprehensive error handling

- **Platform Support**
  - Linux (Ubuntu, Debian, Fedora, Arch, openSUSE)
  - Raspberry Pi OS
  - 64-bit and ARM architectures
  - udev integration for device permissions

### Documentation
- README.md with comprehensive usage instructions
- SETUP.md with detailed installation steps
- API documentation with examples
- Troubleshooting guide
- Security considerations
- Contributing guidelines

### Testing
- Example application for manual testing
- Device discovery verification
- Card reading functionality tests
- Error handling validation
- Cross-platform compatibility testing

## [Unreleased]

### Planned Features
- Windows platform support
- Encrypted data transmission modes
- Additional Magtek device models
- Advanced card validation algorithms
- Configuration management
- Logging and debugging tools