import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mindspore_lite_flutter_method_channel.dart';

abstract class MindsporeLiteFlutterPlatform extends PlatformInterface {
  /// Constructs a MindsporeLiteFlutterPlatform.
  MindsporeLiteFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static MindsporeLiteFlutterPlatform _instance = MethodChannelMindsporeLiteFlutter();

  /// The default instance of [MindsporeLiteFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelMindsporeLiteFlutter].
  static MindsporeLiteFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MindsporeLiteFlutterPlatform] when
  /// they register themselves.
  static set instance(MindsporeLiteFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
