import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/numeric_keypad.dart';
import 'package:preron/widgets/pin_input.dart';
import 'package:preron/widgets/sheet.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  String _pin = '';
  static const int pinLength = 5;
  bool _isLoading = false;

  void _handleKeyPress(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (key != '.' && _pin.length < pinLength) {
        _pin += key;
      }
    });
  }

  void _handleCheckBalance(BuildContext context) async {
    if (_pin.length == pinLength) {
      try{
        setState(() {
          _isLoading = true;
        });
        final selectedSim = await UssdService.getSelectedSim();
        UssdService.startOverlay();
        final response = await UssdService.checkBalance(pin: _pin, simIndex: selectedSim["simIndex"])
            .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception('Session timed out after 45s'),
        );
        UssdService.stopOverlay();
        if(mounted){
          showModalBottomSheet(context: context, builder: (BuildContext ctx) {
            return BalanceBottomSheet(response: response);
          }, backgroundColor: Colors.white);
        }
        if(mounted){
          setState(() {
            _isLoading = false;
          });
        }
      }catch(e){
        UssdService.stopOverlay();

        if(mounted){
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint("Hello"+e.toString());
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final canCheck = _pin.length == pinLength;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "bkash Balance",
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 16),
                Text(
                  "Enter your bkash pin to check your balance",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white),
            height: 500,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                PinInput(value: _pin, pinLength: pinLength, obscureText: true),
                Expanded(
                  child: NumericKeypad(
                    onKeyPressed: _handleKeyPress,
                    showDecimal: false,
                    showBackspace: true,
                  ),
                ),
                SizedBox(height: 16),
                PreronButton(
                  onPressed: canCheck ? (){
                    _handleCheckBalance(context);
                  } : null,
                  text: "Check Balance",
                  isLoading: _isLoading,
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

