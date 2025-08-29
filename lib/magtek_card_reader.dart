/// A Flutter plugin for communicating with Magtek 3-track credit card readers via USB.
/// 
/// This plugin supports reading magnetic stripe cards from Magtek USB card readers
/// on Linux and Raspberry Pi platforms.
library magtek_card_reader;

import 'dart:async';
import 'dart:typed_data';

import 'magtek_card_reader_platform_interface.dart';

export 'src/models/card_data.dart';
export 'src/models/track_data.dart';
export 'src/models/device_info.dart';
export 'src/exceptions/magtek_exceptions.dart';

/// The main class for interacting with Magtek card readers.
class MagtekCardReader {
  static MagtekCardReader? _instance;
  
  /// Get the singleton instance of MagtekCardReader.
  static MagtekCardReader get instance {
    _instance ??= MagtekCardReader._();
    return _instance!;
  }
  
  MagtekCardReader._();

  /// Stream controller for card swipe events.
  final StreamController<CardData> _cardSwipeController = StreamController<CardData>.broadcast();
  
  /// Stream controller for device connection events.
  final StreamController<DeviceInfo> _deviceConnectionController = StreamController<DeviceInfo>.broadcast();
  
  /// Stream controller for error events.
  final StreamController<MagtekException> _errorController = StreamController<MagtekException>.broadcast();

  /// Stream of card swipe events.
  Stream<CardData> get onCardSwipe => _cardSwipeController.stream;
  
  /// Stream of device connection events.
  Stream<DeviceInfo> get onDeviceConnected => _deviceConnectionController.stream;
  
  /// Stream of error events.
  Stream<MagtekException> get onError => _errorController.stream;

  /// Initialize the card reader and start listening for devices.
  Future<void> initialize() async {
    try {
      await MagtekCardReaderPlatform.instance.initialize();
      _startListening();
    } catch (e) {
      _errorController.add(MagtekException('Failed to initialize card reader: $e'));
      rethrow;
    }
  }

  /// Dispose of resources and stop listening.
  Future<void> dispose() async {
    await MagtekCardReaderPlatform.instance.dispose();
    await _cardSwipeController.close();
    await _deviceConnectionController.close();
    await _errorController.close();
  }

  /// Get a list of connected Magtek devices.
  Future<List<DeviceInfo>> getConnectedDevices() async {
    try {
      return await MagtekCardReaderPlatform.instance.getConnectedDevices();
    } catch (e) {
      _errorController.add(MagtekException('Failed to get connected devices: $e'));
      return [];
    }
  }

  /// Connect to a specific device by its device ID.
  Future<bool> connectToDevice(String deviceId) async {
    try {
      return await MagtekCardReaderPlatform.instance.connectToDevice(deviceId);
    } catch (e) {
      _errorController.add(MagtekException('Failed to connect to device: $e'));
      return false;
    }
  }

  /// Disconnect from the currently connected device.
  Future<void> disconnect() async {
    try {
      await MagtekCardReaderPlatform.instance.disconnect();
    } catch (e) {
      _errorController.add(MagtekException('Failed to disconnect: $e'));
    }
  }

  /// Check if a device is currently connected.
  Future<bool> isConnected() async {
    try {
      return await MagtekCardReaderPlatform.instance.isConnected();
    } catch (e) {
      _errorController.add(MagtekException('Failed to check connection status: $e'));
      return false;
    }
  }

  /// Get the platform version for debugging purposes.
  Future<String?> getPlatformVersion() {
    return MagtekCardReaderPlatform.instance.getPlatformVersion();
  }

  /// Start listening for card swipe and device events.
  void _startListening() {
    MagtekCardReaderPlatform.instance.onCardSwipe.listen(
      (cardData) => _cardSwipeController.add(cardData),
      onError: (error) => _errorController.add(MagtekException('Card swipe error: $error')),
    );

    MagtekCardReaderPlatform.instance.onDeviceConnected.listen(
      (deviceInfo) => _deviceConnectionController.add(deviceInfo),
      onError: (error) => _errorController.add(MagtekException('Device connection error: $error')),
    );
  }
}