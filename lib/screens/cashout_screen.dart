import 'package:flutter/material.dart';
import 'package:preron/widgets/amount_input.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/numeric_keypad.dart';
import 'package:preron/widgets/phone_input.dart';
import 'package:preron/widgets/pin_input.dart';

class CashoutScreen extends StatefulWidget {
  const CashoutScreen({super.key});

  @override
  State<CashoutScreen> createState() => _CashoutScreenState();
}

class _CashoutScreenState extends State<CashoutScreen> {


  CashoutStep _currentStep = CashoutStep.phone;

  String _phoneNumber = '';
  String _amount = '';
  String _pin = '';
  static const int pinLength = 5;

  void _handleKeyPress(String key) {
    if(_currentStep == CashoutStep.phone){
      setState(() {
        if (key == 'backspace') {
          if (_phoneNumber.isNotEmpty) {
            _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
          }
        } else if (key != '.') {
          String digitsOnly = _phoneNumber.replaceAll(RegExp(r'\D'), '');
          if (digitsOnly.length < 11) {
            _phoneNumber += key;
          }
        }
      });
    }else if(_currentStep == CashoutStep.amount){
      setState(() {
        if (key == 'backspace') {
          if (_amount.isNotEmpty) {
            _amount = _amount.substring(0, _amount.length - 1);
          }
        } else if (key == '.') {
          if (!_amount.contains('.')) {
            _amount += key;
          }
        } else {
          // Only allow digits
          String digitsOnly = _amount.replaceAll('.', '');
          if (digitsOnly.length < 8) {
            _amount += key;
          }
        }
      });
    }else if(_currentStep == CashoutStep.pin){
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("bkash Cashout", style: Theme.of(context).textTheme.headlineLarge,),
                SizedBox(height: 16,),
                Text(
                  "Enter bKash Agent number to cashout",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.white
            ),
            height: 500,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                if(_currentStep == CashoutStep.phone)PhoneInput(
                  value: _phoneNumber,
                  maxLength: 11,
                ),
                if(_currentStep == CashoutStep.amount)AmountInput(
                  value: _amount,
                  prefixSymbol: '৳',
                  allowDecimal: false,
                  maxDigits: 8,
                ),
                if(_currentStep == CashoutStep.pin)PinInput(
                  value: _pin,
                  pinLength: pinLength,
                  obscureText: true,
                ),
                Expanded(child: NumericKeypad(
                  onKeyPressed: _handleKeyPress,
                  showDecimal: false,
                  showBackspace: true,
                )),
                SizedBox(height: 16,),
                PreronButton(onPressed: (){}, text: "Continue"),
                SizedBox(height: 16,)
              ],
            ),
          )
        ],
      ),
    );
  }
}

enum CashoutStep{
  phone,
  amount,
  pin
}
