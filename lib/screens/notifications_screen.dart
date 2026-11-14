import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';
import '../widgets/linkified_text.dart';
import 'receipt_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<dynamic>? _notes;

  @override
  void initState() {
    super.initState();
    _api.notifications().then((res) => setState(() => _notes = res['success'] == true ? res['notifications'] : []));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _notes == null
          ? const Center(child: CircularProgressIndicator())
          : _notes!.isEmpty
              ? const Center(child: Text('No notifications yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes!.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final n = _notes![i];
                    final reference = n['reference'] as String?;
                    return ListTile(
                      title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: LinkifiedText('${n['message']}', style: Theme.of(context).textTheme.bodyMedium),
                      trailing: (reference == null || reference.isEmpty)
                          ? Text(n['created_at'].toString().substring(5, 16), style: const TextStyle(fontSize: 11))
                          : const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
                      // Tapping a notification about a specific transaction
                      // (a refund, a status change, etc.) opens that
                      // transaction's receipt directly.
                      onTap: (reference == null || reference.isEmpty)
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: reference))),
                    );
                  },
                ),
    );
  }
}
