import 'package:flutter/material.dart';
import 'package:preron/widgets/alphanumeric_keypad.dart';
import 'package:preron/widgets/amount_input.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/numeric_keypad.dart';
import 'package:preron/widgets/phone_input.dart';
import 'package:preron/widgets/pin_input.dart';
import 'package:preron/widgets/reference_input.dart';
import 'package:preron/widgets/send_money_confirm_bottom_sheet.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {

  SendMoneyStep _currentStep = SendMoneyStep.phone;
  String _reference = '';
  String _phoneNumber = '';
  String _amount = '';
  String _pin = '';
  static const int pinLength = 5;

  void _handleKeyPress(String key) {

    if(_currentStep == SendMoneyStep.phone){
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
    }else if (_currentStep == SendMoneyStep.amount) {
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
    }else if(_currentStep == SendMoneyStep.pin){
      setState(() {
        if (key == 'backspace') {
          if (_pin.isNotEmpty) {
            _pin = _pin.substring(0, _pin.length - 1);
          }
        } else if (key != '.' && _pin.length < pinLength) {
          _pin += key;
        }
      });
    }else if(_currentStep == SendMoneyStep.ref){
      setState(() {
        if (key == 'backspace') {
          if (_reference.isNotEmpty) {
            _reference = _reference.substring(0, _reference.length - 1);
          }
        } else if (key != '.') {
          // Only allow alphanumeric (numbers + letters from keypad)
          if (_reference.length < 12) {
            _reference += key.toUpperCase();
          }
        }
      });
    }
  }

  String getSubtitle(){
    if(_currentStep == SendMoneyStep.phone) return "Enter bKash number to send money";
    if(_currentStep == SendMoneyStep.amount) return "Enter amount to send money";
    if(_currentStep == SendMoneyStep.ref) return "Enter reference";
    if(_currentStep == SendMoneyStep.pin) return "Enter your bkash PIN";
    return "";
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

  @override
  Widget build(BuildContext context) {

    final canContinueFromPhone = _phoneNumber.isNotEmpty && _phoneNumber.length == 11;
    final canContinueFromAmount = _isValidAmount;
    final canContinueFromRef = _reference.isNotEmpty && _reference.length >= 2;
    final canContinueFromPin = _pin.isNotEmpty && _pin.length == pinLength;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "bkash Send Money",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  SizedBox(height: 16),
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
                  if(_currentStep == SendMoneyStep.phone)PhoneInput(
                    value: _phoneNumber,
                    maxLength: 11,
                  ),
                  if(_currentStep == SendMoneyStep.amount)AmountInput(
                    value: _amount,
                    prefixSymbol: '৳',
                    allowDecimal: false,
                    maxDigits: 8,
                  ),
                  if(_currentStep == SendMoneyStep.pin)PinInput(
                    value: _pin,
                    pinLength: pinLength,
                    obscureText: true,
                  ),
                  if(_currentStep == SendMoneyStep.ref)ReferenceInput(
                    value: _reference,
                  ),
                  if(_currentStep == SendMoneyStep.phone || _currentStep == SendMoneyStep.pin || _currentStep == SendMoneyStep.amount)Expanded(child: NumericKeypad(
                    onKeyPressed: _handleKeyPress,
                    showDecimal: _currentStep == SendMoneyStep.amount,
                    showBackspace: true,
                  )),
                  if(_currentStep == SendMoneyStep.ref)Expanded(
                    child: AlphanumericKeypad(
                      onKeyPressed: _handleKeyPress,
                      showBackspace: true,
                    ),
                  ),
                  SizedBox(height: 16,),
                  if(_currentStep == SendMoneyStep.phone)PreronButton(onPressed: canContinueFromPhone ? (){
                    setState(() {
                      _currentStep = SendMoneyStep.amount;
                    });
                  } : null, text: "Continue"),
                  if(_currentStep == SendMoneyStep.amount)PreronButton(onPressed: canContinueFromAmount ? (){
                    setState(() {
                      _currentStep = SendMoneyStep.ref;
                    });
                  } : null, text: "Continue"),
                  if(_currentStep == SendMoneyStep.ref)PreronButton(onPressed: canContinueFromRef ? (){
                    setState(() {
                      _currentStep = SendMoneyStep.pin;
                    });
                  } : null, text: "Continue"),
                  if(_currentStep == SendMoneyStep.pin)PreronButton(onPressed: canContinueFromPin ? (){
                    showModalBottomSheet<bool>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SendMoneyConfirmBottomSheet(
                          phoneNumber: _phoneNumber,
                          amount: _amount,
                          ref: _reference,
                          pin: _pin,
                        ),
                        isDismissible: false,
                        enableDrag: false
                    );
                  } : null, text: "Continue"),
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

enum SendMoneyStep{
  phone,
  amount,
  ref,
  pin
}
