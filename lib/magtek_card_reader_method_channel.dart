import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'magtek_card_reader_platform_interface.dart';
import 'src/models/card_data.dart';
import 'src/models/device_info.dart';

/// An implementation of [MagtekCardReaderPlatform] that uses method channels.
class MethodChannelMagtekCardReader extends MagtekCardReaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('magtek_card_reader');

  /// The event channel for card swipe events.
  @visibleForTesting
  final cardSwipeEventChannel = const EventChannel('magtek_card_reader/card_swipe');

  /// The event channel for device connection events.
  @visibleForTesting
  final deviceEventChannel = const EventChannel('magtek_card_reader/device_events');

  StreamSubscription<dynamic>? _cardSwipeSubscription;
  StreamSubscription<dynamic>? _deviceEventSubscription;

  final StreamController<CardData> _cardSwipeController = StreamController<CardData>.broadcast();
  final StreamController<DeviceInfo> _deviceConnectionController = StreamController<DeviceInfo>.broadcast();

  @override
  Stream<CardData> get onCardSwipe => _cardSwipeController.stream;

  @override
  Stream<DeviceInfo> get onDeviceConnected => _deviceConnectionController.stream;

  @override
  Future<void> initialize() async {
    try {
      await methodChannel.invokeMethod('initialize');
      _startListening();
    } catch (e) {
      throw Exception('Failed to initialize card reader: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _cardSwipeSubscription?.cancel();
    await _deviceEventSubscription?.cancel();
    await _cardSwipeController.close();
    await _deviceConnectionController.close();
    
    try {
      await methodChannel.invokeMethod('dispose');
    } catch (e) {
      // Ignore disposal errors
      debugPrint('Error during disposal: $e');
    }
  }

  @override
  Future<List<DeviceInfo>> getConnectedDevices() async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>('getConnectedDevices');
      if (result == null) return [];

      return result.map((deviceMap) {
        final map = Map<String, dynamic>.from(deviceMap as Map);
        return DeviceInfo.fromMap(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get connected devices: $e');
    }
  }

  @override
  Future<bool> connectToDevice(String deviceId) async {
    try {
      final result = await methodChannel.invokeMethod<bool>('connectToDevice', {
        'deviceId': deviceId,
      });
      return result ?? false;
    } catch (e) {
      throw Exception('Failed to connect to device: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await methodChannel.invokeMethod('disconnect');
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } catch (e) {
      throw Exception('Failed to check connection status: $e');
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      throw Exception('Failed to get platform version: $e');
    }
  }

  /// Start listening to event channels.
  void _startListening() {
    // Listen for card swipe events
    _cardSwipeSubscription = cardSwipeEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          if (event is Map) {
            final cardData = CardData.fromRawTracks(
              track1Data: event['track1'] as String?,
              track2Data: event['track2'] as String?,
              track3Data: event['track3'] as String?,
              deviceId: event['deviceId'] as String?,
              rawResponse: event['rawResponse'] as String?,
            );
            _cardSwipeController.add(cardData);
          }
        } catch (e) {
          debugPrint('Error processing card swipe event: $e');
        }
      },
      onError: (dynamic error) {
        debugPrint('Card swipe event error: $error');
      },
    );

    // Listen for device connection events
    _deviceEventSubscription = deviceEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          if (event is Map) {
            final eventType = event['type'] as String?;
            if (eventType == 'device_connected') {
              final deviceMap = Map<String, dynamic>.from(event['device'] as Map);
              final deviceInfo = DeviceInfo.fromMap(deviceMap);
              _deviceConnectionController.add(deviceInfo);
            }
          }
        } catch (e) {
          debugPrint('Error processing device event: $e');
        }
      },
      onError: (dynamic error) {
        debugPrint('Device event error: $error');
      },
    );
  }
}
