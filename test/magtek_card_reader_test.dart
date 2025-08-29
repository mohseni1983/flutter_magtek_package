import 'package:flutter_test/flutter_test.dart';
import 'package:magtek_card_reader/magtek_card_reader.dart';
import 'package:magtek_card_reader/magtek_card_reader_platform_interface.dart';
import 'package:magtek_card_reader/magtek_card_reader_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMagtekCardReaderPlatform
    with MockPlatformInterfaceMixin
    implements MagtekCardReaderPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MagtekCardReaderPlatform initialPlatform = MagtekCardReaderPlatform.instance;

  test('$MethodChannelMagtekCardReader is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMagtekCardReader>());
  });

  test('getPlatformVersion', () async {
    MagtekCardReader magtekCardReaderPlugin = MagtekCardReader();
    MockMagtekCardReaderPlatform fakePlatform = MockMagtekCardReaderPlatform();
    MagtekCardReaderPlatform.instance = fakePlatform;

    expect(await magtekCardReaderPlugin.getPlatformVersion(), '42');
  });
}
