import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/cashout_success_bottom_sheet.dart';

class CashoutConfirmationBottomSheet extends StatefulWidget {
  final String phoneNumber;
  final String amount;
  final String pin;

  const CashoutConfirmationBottomSheet({
    super.key,
    required this.phoneNumber,
    required this.amount,
    required this.pin,
  });

  @override
  State<CashoutConfirmationBottomSheet> createState() =>
      _CashoutConfirmationBottomSheetState();
}

class _CashoutConfirmationBottomSheetState
    extends State<CashoutConfirmationBottomSheet> {
  bool _isLoading = false;

  void _handleCashout(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(Duration(seconds: 5));
      // final sim = await UssdService.getSelectedSim();
      // final response = await UssdService.cashOut(
      //   pin: widget.pin,
      //   simIndex: sim["simIndex"],
      //   phoneNumber: widget.phoneNumber,
      //   amount: widget.amount,
      // ).timeout(
      //   const Duration(seconds: 45),
      //   onTimeout: () => throw Exception('Session timed out after 45s'),
      // );

      setState(() {
        _isLoading = false;
      });
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext ctx) {
          return CashoutSuccessBottomSheet(
            response:
            "Cash Out Tk 980.00 to 01700000000 successful. Fee Tk 18.13. Balance Tk 684.38. TrxID CBH5VCS711. Cash Out from 2 Priyo Agents at 1.49% up to 50,000Tk",
          );
          // return CashoutSuccessBottomSheet(
          //   response: response,
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
    return SafeArea(
      child: PopScope(
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
                'Confirm Cash Out',
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
                    _DetailRow(label: 'Agent Number', value: widget.phoneNumber),
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
