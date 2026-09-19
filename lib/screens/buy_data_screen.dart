import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});
  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _api = ApiService();
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.dataPlans();
    setState(() {
      _plans = res['success'] == true ? res['data_plans'] : [];
      _loading = false;
    });
  }

  void _openBuySheet(Map<String, dynamic> plan) {
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${plan['network']} — ${plan['plan_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('₦${plan['price']} • ${plan['validity']}'),
            const SizedBox(height: 16),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Recipient phone', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: pinCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Transaction PIN', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.buyData(planId: plan['id'], phone: phoneCtrl.text.trim(), transactionPin: pinCtrl.text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
              },
              child: const Text('Confirm Purchase'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (ctx, i) {
                final p = _plans[i];
                return Card(
                  child: ListTile(
                    title: Text('${p['network']} ${p['plan_name']}'),
                    subtitle: Text('${p['validity']} • ${p['type']}'),
                    trailing: Text('₦${p['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _openBuySheet(p),
                  ),
                );
              },
            ),
    );
  }
}
