import 'package:flutter_test/flutter_test.dart';
import 'package:mindspore_lite_flutter/mindspore_lite_flutter.dart';
import 'package:mindspore_lite_flutter/mindspore_lite_flutter_platform_interface.dart';
import 'package:mindspore_lite_flutter/mindspore_lite_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMindsporeLiteFlutterPlatform
    with MockPlatformInterfaceMixin
    implements MindsporeLiteFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MindsporeLiteFlutterPlatform initialPlatform = MindsporeLiteFlutterPlatform.instance;

  test('$MethodChannelMindsporeLiteFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMindsporeLiteFlutter>());
  });

  test('getPlatformVersion', () async {
    MindsporeLiteFlutter mindsporeLiteFlutterPlugin = MindsporeLiteFlutter();
    MockMindsporeLiteFlutterPlatform fakePlatform = MockMindsporeLiteFlutterPlatform();
    MindsporeLiteFlutterPlatform.instance = fakePlatform;

    expect(await mindsporeLiteFlutterPlugin.getPlatformVersion(), '42');
  });
}
