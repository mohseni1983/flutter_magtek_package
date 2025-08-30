// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'magtek_card_reader_platform_interface.dart';
import 'src/models/card_data.dart';
import 'src/models/device_info.dart';
import 'src/exceptions/magtek_exceptions.dart';

/// A web implementation of the MagtekCardReaderPlatform using WebUSB API.
class MagtekCardReaderWeb extends MagtekCardReaderPlatform {
  /// Constructs a MagtekCardReaderWeb
  MagtekCardReaderWeb();

  static void registerWith(Registrar registrar) {
    MagtekCardReaderPlatform.instance = MagtekCardReaderWeb();
  }

  // WebUSB device management
  Object? _currentDevice;
  String? _currentDeviceId;
  bool _isMonitoring = false;
  Timer? _monitoringTimer;

  // Stream controllers for events
  final StreamController<CardData> _cardSwipeController = StreamController<CardData>.broadcast();
  final StreamController<DeviceInfo> _deviceConnectionController = StreamController<DeviceInfo>.broadcast();

  @override
  Stream<CardData> get onCardSwipe => _cardSwipeController.stream;

  @override
  Stream<DeviceInfo> get onDeviceConnected => _deviceConnectionController.stream;

  // Magtek device constants
  static const int _magtekVendorId = 0x0801;
  static const List<int> _magtekProductIds = [
    0x0001, // Magtek Mini Swipe Reader
    0x0002, // Magtek USB Swipe Reader
    0x0003, // Magtek eDynamo
    0x0004, // Magtek uDynamo
    0x0010, // Magtek SureSwipe Reader
  ];

  @override
  Future<String?> getPlatformVersion() async {
    return html.window.navigator.userAgent;
  }

  @override
  Future<void> initialize() async {
    try {
      // Check if WebUSB is supported
      if (!_isWebUsbSupported()) {
        throw PlatformNotSupportedException(
          'WebUSB is not supported in this browser',
          platform: 'web',
        );
      }

      // WebUSB Magtek Card Reader initialized
    } catch (e) {
      throw DeviceInitializationException(
        'Failed to initialize web USB support: $e',
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _stopMonitoring();
      await _disconnectDevice();
      await _cardSwipeController.close();
      await _deviceConnectionController.close();
    } catch (e) {
      // Error during web plugin disposal: $e
    }
  }

  @override
  Future<List<DeviceInfo>> getConnectedDevices() async {
    try {
      if (!_isWebUsbSupported()) {
        return [];
      }

      final devices = await _getUsbDevices();
      final List<DeviceInfo> magtekDevices = [];

      for (final device in devices) {
        final vendorId = js_util.getProperty(device, 'vendorId') as int;
        final productId = js_util.getProperty(device, 'productId') as int;

        if (_isMagtekDevice(vendorId, productId)) {
          final deviceInfo = _createDeviceInfo(device);
          magtekDevices.add(deviceInfo);
        }
      }

      return magtekDevices;
    } catch (e) {
      throw UsbCommunicationException(
        'Failed to get connected devices: $e',
      );
    }
  }

  @override
  Future<bool> connectToDevice(String deviceId) async {
    try {
      if (!_isWebUsbSupported()) {
        throw PlatformNotSupportedException(
          'WebUSB is not supported in this browser',
          platform: 'web',
        );
      }

      // Request device access with Magtek device filters
      final device = await _requestUsbDevice();
      if (device == null) {
        return false;
      }

      final vendorId = js_util.getProperty(device, 'vendorId') as int;
      final productId = js_util.getProperty(device, 'productId') as int;

      if (!_isMagtekDevice(vendorId, productId)) {
        throw DeviceConnectionException(
          'Selected device is not a Magtek card reader',
          deviceId: deviceId,
        );
      }

      // Open device connection
      await js_util.promiseToFuture(js_util.callMethod(device, 'open', []));

      // Select configuration (usually configuration 1)
      await _selectConfiguration(device, 1);

      // Claim the HID interface
      await _claimInterface(device);

      _currentDevice = device;
      _currentDeviceId = deviceId;

      // Start monitoring for card swipes
      _startMonitoring();

      // Notify device connection
      final deviceInfo = _createDeviceInfo(device);
      _deviceConnectionController.add(deviceInfo);

      // Connected to Magtek device: ${deviceInfo.deviceName}
      return true;
    } catch (e) {
      throw DeviceConnectionException(
        'Failed to connect to device: $e',
        deviceId: deviceId,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _disconnectDevice();
  }

  @override
  Future<bool> isConnected() async {
    return _currentDevice != null;
  }

  Future<void> _disconnectDevice() async {
    try {
      _stopMonitoring();

      if (_currentDevice != null) {
        // Close the device connection
        await js_util.promiseToFuture(
          js_util.callMethod(_currentDevice!, 'close', [])
        );
        
        _currentDevice = null;
        _currentDeviceId = null;
        // Disconnected from Magtek device
      }
    } catch (e) {
      // Error disconnecting device: $e
    }
  }

  void _startMonitoring() {
    if (_isMonitoring || _currentDevice == null) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _readFromDevice();
    });
    
    // Started device monitoring
  }

  void _stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    // Stopped device monitoring
  }

  Future<void> _readFromDevice() async {
    if (_currentDevice == null || !_isMonitoring) return;

    try {
      // Try to read from HID interrupt endpoint
      final result = await js_util.promiseToFuture(
        js_util.callMethod(_currentDevice!, 'transferIn', [1, 64]) // endpoint 1, 64 bytes
      );

      final status = js_util.getProperty(result, 'status') as String;
      if (status == 'ok') {
        final data = js_util.getProperty(result, 'data');
        final buffer = js_util.getProperty(data, 'buffer');
        
        if (buffer != null) {
          final bytes = Uint8List.fromList(
            List<int>.from(js_util.getProperty(buffer, 'data') ?? [])
          );
          
          if (bytes.isNotEmpty) {
            final cardData = _parseInputReport(bytes);
            if (cardData.track1?.rawData?.isNotEmpty == true ||
                cardData.track2?.rawData?.isNotEmpty == true ||
                cardData.track3?.rawData?.isNotEmpty == true) {
              _cardSwipeController.add(cardData);
              // Card swipe detected via WebUSB
            }
          }
        }
      }
    } catch (e) {
      // Ignore read errors for now (device might not have data)
      // print('Read error: $e');
    }
  }

  CardData _parseInputReport(Uint8List data) {
    final timestamp = DateTime.now();
    final rawResponse = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    if (data.length < 2) {
      return CardData(
        track1: null,
        track2: null, 
        track3: null,
        timestamp: timestamp,
        hasValidData: false,
        deviceId: _currentDeviceId,
        rawResponse: rawResponse,
      );
    }

    // Convert to string, skipping first byte (report ID)
    final dataString = String.fromCharCodes(
      data.skip(1).where((byte) => byte >= 0x20 && byte <= 0x7E)
    );

    if (dataString.isEmpty) {
      return CardData(
        track1: null,
        track2: null,
        track3: null,
        timestamp: timestamp,
        hasValidData: false,
        deviceId: _currentDeviceId,
        rawResponse: rawResponse,
      );
    }

    // Parse track data
    String? track1;
    String? track2;
    String? track3;

    // Track 1: Starts with '%', ends with '?'
    final track1Start = dataString.indexOf('%');
    if (track1Start != -1) {
      final track1End = dataString.indexOf('?', track1Start);
      if (track1End != -1) {
        track1 = dataString.substring(track1Start, track1End + 1);
      }
    }

    // Track 2: Starts with ';', ends with '?'
    final track2Start = dataString.indexOf(';');
    if (track2Start != -1) {
      final track2End = dataString.indexOf('?', track2Start);
      if (track2End != -1) {
        track2 = dataString.substring(track2Start, track2End + 1);
      }
    }

    return CardData.fromRawTracks(
      track1Data: track1,
      track2Data: track2,
      track3Data: track3,
      deviceId: _currentDeviceId,
      rawResponse: rawResponse,
    );
  }

  DeviceInfo _createDeviceInfo(Object device) {
    final vendorId = js_util.getProperty(device, 'vendorId') as int;
    final productId = js_util.getProperty(device, 'productId') as int;
    final serialNumber = js_util.getProperty(device, 'serialNumber') as String?;
    
    return DeviceInfo(
      deviceId: '${vendorId.toRadixString(16)}:${productId.toRadixString(16)}:${serialNumber ?? 'unknown'}',
      deviceName: _getDeviceName(vendorId, productId),
      vendorId: vendorId,
      productId: productId,
      serialNumber: serialNumber,
      devicePath: 'WebUSB',
      isConnected: _currentDevice == device,
    );
  }

  bool _isWebUsbSupported() {
    return js_util.hasProperty(html.window.navigator, 'usb');
  }

  Future<List<Object>> _getUsbDevices() async {
    final usb = js_util.getProperty(html.window.navigator, 'usb');
    final devicesPromise = js_util.callMethod(usb, 'getDevices', []);
    final devices = await js_util.promiseToFuture<List<Object>>(devicesPromise);
    return devices;
  }

  Future<Object?> _requestUsbDevice() async {
    try {
      final usb = js_util.getProperty(html.window.navigator, 'usb');
      
      // Create device filters for Magtek devices
      final filters = _magtekProductIds.map((productId) => {
        'vendorId': _magtekVendorId,
        'productId': productId,
      }).toList();

      final options = {'filters': filters};
      
      final devicePromise = js_util.callMethod(usb, 'requestDevice', [js_util.jsify(options)]);
      return await js_util.promiseToFuture<Object?>(devicePromise);
    } catch (e) {
      // User cancelled device selection or error: $e
      return null;
    }
  }

  Future<void> _selectConfiguration(Object device, int configurationValue) async {
    await js_util.promiseToFuture(
      js_util.callMethod(device, 'selectConfiguration', [configurationValue])
    );
  }

  Future<void> _claimInterface(Object device) async {
    // Claim the HID interface (usually interface 0)
    await js_util.promiseToFuture(
      js_util.callMethod(device, 'claimInterface', [0])
    );
  }

  bool _isMagtekDevice(int vendorId, int productId) {
    return vendorId == _magtekVendorId && _magtekProductIds.contains(productId);
  }

  String _getDeviceName(int vendorId, int productId) {
    if (vendorId != _magtekVendorId) {
      return 'Unknown Device';
    }

    switch (productId) {
      case 0x0001:
        return 'Magtek Mini Swipe Reader';
      case 0x0002:
        return 'Magtek USB Swipe Reader';
      case 0x0003:
        return 'Magtek eDynamo';
      case 0x0004:
        return 'Magtek uDynamo';
      case 0x0010:
        return 'Magtek SureSwipe Reader';
      default:
        return 'Magtek Card Reader (PID: 0x${productId.toRadixString(16).padLeft(4, '0')})';
    }
  }
}
