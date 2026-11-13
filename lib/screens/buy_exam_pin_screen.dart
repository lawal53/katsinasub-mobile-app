import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../widgets/pin_field.dart';
import '../widgets/service_picker.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class BuyExamPinScreen extends StatefulWidget {
  const BuyExamPinScreen({super.key});
  @override
  State<BuyExamPinScreen> createState() => _BuyExamPinScreenState();
}

class _BuyExamPinScreenState extends State<BuyExamPinScreen> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  List<dynamic> _exams = [];
  String? _selectedExam;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.examPlans();
    setState(() {
      _exams = res['success'] == true ? res['exams'] : [];
      _loading = false;
    });
  }

  double get _unitPrice {
    final e = _exams.firstWhere((e) => e['exam_name'] == _selectedExam, orElse: () => null);
    return e == null ? 0 : (e['price'] as num).toDouble();
  }

  double get _total => _unitPrice * (int.tryParse(_qtyCtrl.text) ?? 1);

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.buyExamPin(
      exam: _selectedExam!,
      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
      phone: _phoneCtrl.text.trim(),
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;

    final pin = res['pin'];
    final shown = Map<String, dynamic>.from(res);
    if (pin is String && pin.isNotEmpty) {
      shown['message'] = '${res['message'] ?? 'Successful'}\nPIN(s): $pin';
    }
    await showPurchaseResult(context, shown);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Pins')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const StepLabel('Select Examination'),
          ServiceGrid(
            names: _exams.map<String>((e) => '${e['exam_name']}').toList(),
            subtitles: {for (final e in _exams) '${e['exam_name']}': '₦${nairaAmount(e['price'])}'},
            selected: _selectedExam,
            onPick: (n) => setState(() => _selectedExam = n),
          ),
          if (_selectedExam != null) ...[
          const SizedBox(height: 22),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Quantity'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('Phone Number (PIN sent via SMS)'), hintText: tr('08012345678'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Amount to be deducted'), Text('₦${nairaAmount(_total)}', style: const TextStyle(fontWeight: FontWeight.bold))],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _selectedExam == null ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Buy Pin'),
          ),
          ],
        ],
      ),
    );
  }
}
