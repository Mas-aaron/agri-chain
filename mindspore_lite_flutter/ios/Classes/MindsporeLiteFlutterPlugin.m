#import "MindsporeLiteFlutterPlugin.h"
#import <mindspore_lite_flutter/mindspore_lite_flutter-Swift.h>

@implementation MindsporeLiteFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftMindsporeLiteFlutterPlugin registerWithRegistrar:registrar];
}
@end
