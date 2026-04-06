import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/send_money_success_bottom_sheet.dart';

class SendMoneyConfirmBottomSheet extends StatefulWidget {

  final String phoneNumber;
  final String amount;
  final String pin;
  final String ref;

  const SendMoneyConfirmBottomSheet({
    super.key,
    required this.phoneNumber,
    required this.amount,
    required this.pin,
    required this.ref,
  });

  @override
  State<SendMoneyConfirmBottomSheet> createState() => _SendMoneyConfirmBottomSheetState();
}

class _SendMoneyConfirmBottomSheetState extends State<SendMoneyConfirmBottomSheet> {

  bool _isLoading = false;

  void _handleCashout(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final sim = await UssdService.getSelectedSim();
      final response = await UssdService.sendMoney(
        pin: widget.pin,
        simIndex: sim["simIndex"],
        phoneNumber: widget.phoneNumber,
        amount: widget.amount,
        reference: widget.ref,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw Exception('Session timed out after 45s'),
      );

      await Future.delayed(const Duration(seconds: 5));
      setState(() {
        _isLoading = false;
      });
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext ctx) {
          return SendMoneySuccessBottomSheet(
            response: response,
          );
          // return SendMoneySuccessBottomSheet(
          //   response:
          //   "Send Money Tk 1,995.00 to 01700000000 successful. Ref ABF. Fee Tk 5.00. Balance Tk 0.03. TrxID CDJ3HEIBC1",
          // );
        },
        backgroundColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isLoading,
      onPopInvokedWithResult: (didPop, result) {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Confirm Send Money',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Receiver', value: widget.phoneNumber),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Reference', value: widget.ref),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Amount',
                    value: '৳ ${widget.amount}',
                    valueStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PreronButton(
              onPressed: () {
                _handleCashout(context);
              },
              text: "Confirm",
              isLoading: _isLoading,
            ),
            if (!_isLoading) const SizedBox(height: 12),
            if (!_isLoading)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style:
          valueStyle ??
              const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
        ),
      ],
    );
  }
}
