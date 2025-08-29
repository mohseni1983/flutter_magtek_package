import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'magtek_card_reader_method_channel.dart';
import 'src/models/card_data.dart';
import 'src/models/device_info.dart';

abstract class MagtekCardReaderPlatform extends PlatformInterface {
  /// Constructs a MagtekCardReaderPlatform.
  MagtekCardReaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static MagtekCardReaderPlatform _instance = MethodChannelMagtekCardReader();

  /// The default instance of [MagtekCardReaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelMagtekCardReader].
  static MagtekCardReaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MagtekCardReaderPlatform] when
  /// they register themselves.
  static set instance(MagtekCardReaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Stream of card swipe events.
  Stream<CardData> get onCardSwipe {
    throw UnimplementedError('onCardSwipe has not been implemented.');
  }

  /// Stream of device connection events.
  Stream<DeviceInfo> get onDeviceConnected {
    throw UnimplementedError('onDeviceConnected has not been implemented.');
  }

  /// Initialize the card reader plugin.
  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Dispose of plugin resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Get a list of connected Magtek devices.
  Future<List<DeviceInfo>> getConnectedDevices() {
    throw UnimplementedError('getConnectedDevices() has not been implemented.');
  }

  /// Connect to a specific device by its device ID.
  Future<bool> connectToDevice(String deviceId) {
    throw UnimplementedError('connectToDevice() has not been implemented.');
  }

  /// Disconnect from the currently connected device.
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Check if a device is currently connected.
  Future<bool> isConnected() {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  /// Get the platform version for debugging purposes.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
