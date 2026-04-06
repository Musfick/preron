import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;

class UssdService {
  static const _method = MethodChannel('com.github.musfick.preron.preron/ussd');
  static const _events = EventChannel('com.github.musfick.preron.preron/ussd_events');

  static Future<Map<String, dynamic>> getSelectedSim() async {
    final result = prefs.getString('selected_sim_carrier_name');
    final sims = await getSimCards();
    if(result == null) return sims.first;
    return sims.firstWhere((e) => e['carrierName'] == result);
  }

  static Future<void> setSelectedSim(Map<String, dynamic> sim) async {
    await prefs.setString('selected_sim_carrier_name', sim['carrierName']);
  }

  static Stream<Map> get eventStream =>
      _events.receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e));

  static Future<bool> checkAccessibility() async =>
      await _method.invokeMethod('checkAccessibilityEnabled') as bool;

  static Future<void> openAccessibilitySettings() async =>
      await _method.invokeMethod('openAccessibilitySettings');

  /// Returns list of SIM cards:
  /// [{"simIndex": 0, "displayName": "SIM 1", "carrierName": "GP", ...}]
  static Future<List<Map<String, dynamic>>> getSimCards() async {
    final raw = await _method.invokeMethod('getSimCards') as List;
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Check balance on a specific SIM with PIN.
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

  /// Send money to a bKash/Nagad number.
  ///
  /// [phoneNumber] — recipient mobile number (e.g. "01XXXXXXXXX")
  /// [amount]      — amount as a string (e.g. "500")
  /// [reference]   — optional transaction reference / note
  static Future<String> sendMoney({
    required String pin,
    required int simIndex,
    required String phoneNumber,
    required String amount,
    String reference = '',
  }) async {
    final result = await _method.invokeMethod('sendMoney', {
      'pin': pin,
      'simIndex': simIndex,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'reference': reference,
    });
    return result as String;
  }

  /// Cash out to an agent number.
  ///
  /// [phoneNumber] — agent mobile number (e.g. "01XXXXXXXXX")
  /// [amount]      — amount as a string (e.g. "500")
  static Future<String> cashOut({
    required String pin,
    required int simIndex,
    required String phoneNumber,
    required String amount,
  }) async {
    final result = await _method.invokeMethod('cashOut', {
      'pin': pin,
      'simIndex': simIndex,
      'phoneNumber': phoneNumber,
      'amount': amount,
    });
    return result as String;
  }
}