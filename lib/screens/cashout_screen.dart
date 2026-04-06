import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/amount_input.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/cashout_confirm_bottom_sheet.dart';
import 'package:preron/widgets/cashout_success_bottom_sheet.dart';
import 'package:preron/widgets/numeric_keypad.dart';
import 'package:preron/widgets/phone_input.dart';
import 'package:preron/widgets/pin_input.dart';
import 'package:preron/widgets/sheet.dart';

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
    }else if (_currentStep == CashoutStep.amount) {
      setState(() {
        if (key == 'backspace') {
          if (_amount.isNotEmpty) {
            _amount = _amount.substring(0, _amount.length - 1);
          }
        } else if (key == '.') {
          if (!_amount.contains('.') && _amount.isNotEmpty) {
            _amount += '.';
          }
        } else {
          // Only allow digits, enforce max 30000 and 2 decimal places
          if (_amount.contains('.')) {
            final parts = _amount.split('.');
            if (parts[1].length < 2) {
              final newAmount = _amount + key;
              if (double.tryParse(newAmount) != null && double.parse(newAmount) <= 30000) {
                _amount = newAmount;
              }
            }
          } else {
            final newAmount = _amount + key;
            if (double.tryParse(newAmount) != null && double.parse(newAmount) <= 30000) {
              _amount = newAmount;
            }
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

  bool get _isValidAmount {
    if (_amount.isEmpty) return false;

    // Remove trailing dot before parsing
    final cleaned = _amount.endsWith('.') ? _amount.replaceAll('.', '') : _amount;

    final value = double.tryParse(cleaned);
    if (value == null) return false;
    if (value < 5) return false;
    if (value > 30000) return false;

    // Block inputs like "00", "000", "0100" — leading zeros on multi-digit int part
    final intPart = _amount.split('.')[0];
    if (intPart.length > 1 && intPart.startsWith('0')) return false;

    return true;
  }

  String getSubtitle(){
    if(_currentStep == CashoutStep.phone) return "Enter bKash Agent number to cashout";
    if(_currentStep == CashoutStep.amount) return "Enter amount to cashout";
    if(_currentStep == CashoutStep.pin) return "Enter your bkash PIN";
    return "";
  }


  @override
  Widget build(BuildContext context) {
    final canContinueToAmount = _phoneNumber.isNotEmpty && _phoneNumber.length == 11;
    final canContinueToPin = _isValidAmount;
    final canConfirmCashout = _pin.isNotEmpty && _pin.length == pinLength;
    return PopScope(
      canPop: _currentStep == CashoutStep.phone,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if(_currentStep == CashoutStep.pin){
          setState(() {
            _currentStep = CashoutStep.amount;
          });
        }else if(_currentStep == CashoutStep.amount){
          setState(() {
            _currentStep = CashoutStep.phone;
          });
        }
      },
      child: Scaffold(
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
                    getSubtitle(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
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
                    showDecimal: _currentStep == CashoutStep.amount,
                    showBackspace: true,
                  )),
                  SizedBox(height: 16,),
                  if(_currentStep == CashoutStep.phone)PreronButton(onPressed: canContinueToAmount ? () async {
                    setState(() {
                      _currentStep = CashoutStep.amount;
                    });
                  } : null, text: "Continue"),
                  if(_currentStep == CashoutStep.amount)PreronButton(onPressed: canContinueToPin ? (){
                    setState(() {
                      _currentStep = CashoutStep.pin;
                    });
                  } : null, text: "Continue"),
                  if(_currentStep == CashoutStep.pin)PreronButton(onPressed: canConfirmCashout ? (){
                    showModalBottomSheet<bool>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CashoutConfirmationBottomSheet(
                          phoneNumber: _phoneNumber,
                          amount: _amount,
                          pin: _pin,
                        ),
                        isDismissible: false,
                        enableDrag: false
                    );
                  } : null, text: "Continue",),
                  SizedBox(height: 16,)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

enum CashoutStep{
  phone,
  amount,
  pin
}
