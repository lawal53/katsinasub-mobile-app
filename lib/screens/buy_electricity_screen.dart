import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BuyElectricityScreen extends StatefulWidget {
  const BuyElectricityScreen({super.key});
  @override
  State<BuyElectricityScreen> createState() => _BuyElectricityScreenState();
}

class _BuyElectricityScreenState extends State<BuyElectricityScreen> {
  final _api = ApiService();
  final _meterCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<dynamic> _discos = [];
  String? _selectedDisco;
  String _meterType = 'prepaid';
  bool _loading = true;
  bool _busy = false;

  Map<String, dynamic>? _verification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.electricityDiscos();
    setState(() {
      _discos = res['success'] == true ? res['discos'] : [];
      _selectedDisco = _discos.isNotEmpty ? _discos.first : null;
      _loading = false;
    });
  }

  Future<void> _verify() async {
    if (_selectedDisco == null || _meterCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final res = await _api.verifyElectricity(
      disco: _selectedDisco!,
      meterType: _meterType,
      meterNumber: _meterCtrl.text.trim(),
    );
    setState(() => _busy = false);
    if (res['success'] == true) {
      setState(() => _verification = res);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Verification failed')));
    }
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum electricity payment is ₦500.')));
      return;
    }
    setState(() => _busy = true);
    final res = await _api.buyElectricity(
      disco: _verification!['disco'],
      meterType: _verification!['meter_type'],
      meterNumber: _verification!['meter_number'],
      phone: _phoneCtrl.text.trim(),
      amount: amount,
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Electricity Bill')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_verification == null) ...[
            // ---- STEP 1: pick disco + meter, then verify ----
            const Text('Electricity Company (Disco)', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: _selectedDisco,
              isExpanded: true,
              items: _discos.map<DropdownMenuItem<String>>((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _selectedDisco = v),
            ),
            const SizedBox(height: 12),
            const Text('Meter Type', style: TextStyle(fontWeight: FontWeight.bold)),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'prepaid', label: Text('Prepaid')),
                ButtonSegment(value: 'postpaid', label: Text('Postpaid')),
              ],
              selected: {_meterType},
              onSelectionChanged: (s) => setState(() => _meterType = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meterCtrl,
              decoration: const InputDecoration(labelText: 'Meter Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy ? const CircularProgressIndicator() : const Text('Verify Name & Continue'),
            ),
          ] else ...[
            // ---- STEP 2: confirm name, enter phone/amount/PIN, pay ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confirm Before Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    if ((_verification!['verified_name'] as String).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('Customer Name: ${_verification!['verified_name']}'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Could not verify name automatically — double check the meter number before paying.'),
                      ),
                    const SizedBox(height: 10),
                    Text('${_verification!['disco']} — ${_verification!['meter_type']}'),
                    Text('Meter: ${_verification!['meter_number']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₦, min 500)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', hintText: '08012345678', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Transaction PIN', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: _busy ? const CircularProgressIndicator() : const Text('Confirm & Pay'),
            ),
            TextButton(
              onPressed: () => setState(() => _verification = null),
              child: const Text('Go back'),
            ),
          ],
        ],
      ),
    );
  }
}
