import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _api.referral().then((res) => setState(() => _data = res));
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final referred = _data!['referred'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text('Referral')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Referral Code', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(_data!['referral_code'], style: const TextStyle(fontSize: 18))),
                      IconButton(icon: const Icon(Icons.copy), onPressed: () => _copy(_data!['referral_code'])),
                    ],
                  ),
                  const Divider(),
                  const Text('Referral Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(_data!['referral_link'], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      IconButton(icon: const Icon(Icons.copy), onPressed: () => _copy(_data!['referral_link'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((_data!['bonus_amount'] as num) > 0)
                    Text('You earn ₦${_data!['bonus_amount']} every time someone you refer funds their wallet for the first time.', style: const TextStyle(fontSize: 12.5))
                  else
                    const Text('Admin has not enabled the referral bonus yet.', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('People You\'ve Referred (${_data!['referred_count']})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (referred.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('No referrals yet.'))
          else
            ...referred.map((r) => Card(
                  child: ListTile(
                    title: Text(r['full_name']),
                    subtitle: Text(r['email']),
                    trailing: Text(r['created_at'].toString().split(' ').first),
                  ),
                )),
        ],
      ),
    );
  }
}
