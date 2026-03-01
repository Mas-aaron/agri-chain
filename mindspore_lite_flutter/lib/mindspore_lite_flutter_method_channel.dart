import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mindspore_lite_flutter_platform_interface.dart';

/// An implementation of [MindsporeLiteFlutterPlatform] that uses method channels.
class MethodChannelMindsporeLiteFlutter extends MindsporeLiteFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.agrichain.mindspore');


  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
