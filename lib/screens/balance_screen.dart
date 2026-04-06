import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/numeric_keypad.dart';
import 'package:preron/widgets/pin_input.dart';

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
        final response = await UssdService.checkBalance(pin: _pin, simIndex: 0)
            .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception('Session timed out after 45s'),
        );
        final balance = extractBalance(response);
        if(mounted && balance != null){
          showModalBottomSheet(context: context, builder: (BuildContext ctx) {
            return BalanceBottomSheet(balance: balance);
          }, backgroundColor: Colors.white);
        }
        if(mounted){
          setState(() {
            _isLoading = false;
          });
        }
      }catch(e){
        if(mounted){
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint(e.toString());
      }
    }
  }

  double? extractBalance(String ussdResponse) {
    final regex = RegExp(r'Available balance Tk ([\d,]+\.?\d*)');
    final match = regex.firstMatch(ussdResponse);
    if (match == null) return null;

    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
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

class BalanceBottomSheet extends StatefulWidget {
  final double balance;
  const BalanceBottomSheet({super.key, required this.balance});

  @override
  State<BalanceBottomSheet> createState() => _BalanceBottomSheetState();
}

class _BalanceBottomSheetState extends State<BalanceBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Tk ${widget.balance}", style: Theme.of(context).textTheme.headlineMedium,),
                SizedBox(height: 8,),
                Text("Your Current balance", style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant
                ),),
              ],
            ),
          ),
          SizedBox(height: 16,),
          PreronButton(onPressed: (){
            Navigator.pop(context);
            Navigator.pop(context);
          }, text: "Back to Home"),
          SizedBox(height: 16,),
        ],
      ),
    );
  }
}

