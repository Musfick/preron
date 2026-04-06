import 'package:flutter/services.dart';

class UssdService {
  static const _method = MethodChannel('com.github.musfick.preron.preron/ussd');
  static const _events = EventChannel('com.github.musfick.preron.preron/ussd_events');

  static Stream<Map> get eventStream =>
      _events.receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e));

  static Future<bool> checkAccessibility() async =>
      await _method.invokeMethod('checkAccessibilityEnabled') as bool;

  static Future<void> openAccessibilitySettings() async =>
      await _method.invokeMethod('openAccessibilitySettings');

  /// Returns list of SIM cards in format:
  /// [{"simIndex": 0, "displayName": "SIM 1", "carrierName": "GP", ...}]
  static Future<List<Map<String, dynamic>>> getSimCards() async {
    final raw = await _method.invokeMethod('getSimCards') as List;
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Check balance on specific SIM with PIN
  static Future<String> checkBalance({
    required String pin,
    required int simIndex,
  }) async {
    final result = await _method.invokeMethod('checkBalance', {
      'pin': pin,
      'simIndex': simIndex,
    });
    return result as String;
  }
}
