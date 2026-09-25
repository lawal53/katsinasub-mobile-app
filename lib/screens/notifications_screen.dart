import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

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
                    return ListTile(
                      title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(n['message']),
                      trailing: Text(n['created_at'].toString().substring(5, 16), style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
    );
  }
}
