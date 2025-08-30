import 'package:flutter_test/flutter_test.dart';
import 'package:magtek_card_reader/magtek_card_reader_platform_interface.dart';
import 'package:magtek_card_reader/magtek_card_reader_method_channel.dart';
import 'package:magtek_card_reader/src/models/card_data.dart';
import 'package:magtek_card_reader/src/models/device_info.dart';
import 'package:magtek_card_reader/src/exceptions/magtek_exceptions.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMagtekCardReaderPlatform
    with MockPlatformInterfaceMixin
    implements MagtekCardReaderPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Stream<CardData> get onCardSwipe => Stream.empty();

  @override
  Stream<DeviceInfo> get onDeviceConnected => Stream.empty();

  @override
  Stream<MagtekException> get onError => Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<DeviceInfo>> getConnectedDevices() async => [];

  @override
  Future<bool> connectToDevice(String deviceId) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => false;
}

void main() {
  final MagtekCardReaderPlatform initialPlatform = MagtekCardReaderPlatform.instance;

  test('$MethodChannelMagtekCardReader is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMagtekCardReader>());
  });

  test('getPlatformVersion', () async {
    MockMagtekCardReaderPlatform fakePlatform = MockMagtekCardReaderPlatform();
    MagtekCardReaderPlatform.instance = fakePlatform;

    expect(await fakePlatform.getPlatformVersion(), '42');
  });
}
