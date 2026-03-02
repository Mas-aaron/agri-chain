import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspore_lite_flutter/mindspore_lite_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMindsporeLiteFlutter platform = MethodChannelMindsporeLiteFlutter();
  const MethodChannel channel = MethodChannel('mindspore_lite_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
