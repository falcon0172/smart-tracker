//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<share_plus/FPPSharePlusPlugin.h>)
#import <share_plus/FPPSharePlusPlugin.h>
#else
@import share_plus;
#endif

#if __has_include(<sqlite3_flutter_libs/Sqlite3FlutterLibsPlugin.h>)
#import <sqlite3_flutter_libs/Sqlite3FlutterLibsPlugin.h>
#else
@import sqlite3_flutter_libs;
#endif

#if __has_include(<universal_ble/UniversalBlePlugin.h>)
#import <universal_ble/UniversalBlePlugin.h>
#else
@import universal_ble;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [Sqlite3FlutterLibsPlugin registerWithRegistrar:[registry registrarForPlugin:@"Sqlite3FlutterLibsPlugin"]];
  [UniversalBlePlugin registerWithRegistrar:[registry registrarForPlugin:@"UniversalBlePlugin"]];
}

@end
