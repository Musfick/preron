import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CashoutSuccessBottomSheet extends StatefulWidget {
  final String response;
  const CashoutSuccessBottomSheet({super.key, required this.response});

  @override
  State<CashoutSuccessBottomSheet> createState() => _CashoutSuccessBottomSheetState();
}

class _CashoutSuccessBottomSheetState extends State<CashoutSuccessBottomSheet> {
  late _ParsedCashout _data;

  @override
  void initState() {
    super.initState();
    _data = _ParsedCashout.fromResponse(widget.response);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Success icon
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFECFAF3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF1DB95A),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Cash Out Successful',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),

            // Amount
            Text(
              '৳ ${_data.amount}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Agent Number', value: _data.agentNumber),
                  const _Divider(),
                  _DetailRow(label: 'Fee', value: '৳ ${_data.fee}'),
                  const _Divider(),
                  _DetailRow(label: 'Balance', value: '৳ ${_data.balance}'),
                  const _Divider(),
                  _TrxRow(trxId: _data.trxId),
                  const _Divider(),
                  _DetailRow(label: 'Date & Time', value: _data.dateTime),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Back to Home
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Home',
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

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A))),
      ],
    );
  }
}

class _TrxRow extends StatefulWidget {
  final String trxId;
  const _TrxRow({required this.trxId});

  @override
  State<_TrxRow> createState() => _TrxRowState();
}

class _TrxRowState extends State<_TrxRow> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.trxId));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Transaction ID',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        Row(
          children: [
            Text(widget.trxId,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _copy,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _copied
                    ? const Icon(Icons.check_rounded,
                    key: ValueKey('check'), size: 16, color: Color(0xFF1DB95A))
                    : Icon(Icons.copy_rounded,
                    key: const ValueKey('copy'),
                    size: 16,
                    color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Parser ────────────────────────────────────────────────────────────────────

class _ParsedCashout {
  final String agentNumber;
  final String amount;
  final String fee;
  final String balance;
  final String trxId;
  final String dateTime;

  _ParsedCashout({
    required this.agentNumber,
    required this.amount,
    required this.fee,
    required this.balance,
    required this.trxId,
    required this.dateTime,
  });

  factory _ParsedCashout.fromResponse(String response) {
    String _get(RegExp pattern, String fallback) {
      final m = pattern.firstMatch(response);
      return m?.group(1)?.trim() ?? fallback;
    }

    final amount     = _get(RegExp(r'Cash Out Tk\s+([\d.]+)'), '—');
    final agent      = _get(RegExp(r'to\s+([\d]+)'), '—');
    final fee        = _get(RegExp(r'Fee Tk\s+([\d.]+)'), '—').removeLast();
    final balance    = _get(RegExp(r'Balance Tk\s+([\d.]+)'), '—').removeLast();
    final trxId      = _get(RegExp(r'TrxID\s+(\S+)'), '—').removeLast();

    final now        = DateTime.now();
    String _formatHour(int hour) => (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');
    String _amPm(int hour) => hour < 12 ? 'AM' : 'PM';

    final dateTime =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${_formatHour(now.hour)}:${now.minute.toString().padLeft(2, '0')} ${_amPm(now.hour)}';

    return _ParsedCashout(
      agentNumber: agent,
      amount: amount,
      fee: fee,
      balance: balance,
      trxId: trxId,
      dateTime: dateTime,
    );
  }
}

extension StringExt on String {
  String removeLast() {
    if (isEmpty) return this;
    return substring(0, length - 1);
  }
}