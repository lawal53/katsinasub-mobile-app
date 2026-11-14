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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes!.length,
                  itemBuilder: (ctx, i) {
                    final n = _notes![i];
                    final reference = n['reference'] as String?;
                    final title = '${n['title']}';
                    final low = title.toLowerCase();
                    final Color color = low.contains('refund') ? const Color(0xFF1B9E55) : (low.contains('fail') ? const Color(0xFFD64545) : (low.contains('reward') || low.contains('bonus') ? const Color(0xFFE67E22) : const Color(0xFF2F6FED)));
                    final IconData icon = low.contains('refund') ? Icons.undo_rounded : (low.contains('fail') ? Icons.error_outline : (low.contains('reward') || low.contains('bonus') ? Icons.card_giftcard : Icons.notifications_none_rounded));
                    final tappable = !(reference == null || reference.isEmpty);
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        // Tapping a notification about a specific transaction (a refund,
                        // a status change, etc.) opens that transaction's receipt directly.
                        onTap: tappable ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: reference))) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                                child: Icon(icon, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                                    const SizedBox(height: 3),
                                    LinkifiedText('${n['message']}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 6),
                                    Text(n['created_at'].toString().substring(5, 16), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (tappable) const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
