import 'package:flutter/material.dart';
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
      _selectedExam = _exams.isNotEmpty ? _exams.first['exam_name'] : null;
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

    if (res['pin'] != null && (res['pin'] as String).isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Your PIN(s)'),
          content: SelectableText(res['pin']),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    }
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Pins')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Select Exam', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _exams.map<Widget>((e) => ChoiceChip(
                  label: Text('${e['exam_name']} (₦${e['price']})'),
                  selected: _selectedExam == e['exam_name'],
                  onSelected: (_) => setState(() => _selectedExam = e['exam_name']),
                )).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number (PIN sent via SMS)', hintText: '08012345678', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Transaction PIN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Amount to be deducted'), Text('₦${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _selectedExam == null ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Buy Pin'),
          ),
        ],
      ),
    );
  }
}
