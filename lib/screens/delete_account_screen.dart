import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

/// The customer tells us why they want to delete their account.
/// An admin then approves or rejects the request.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _api = ApiService();
  final _reasonCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.deleteAccountStatus();
      if (res['success'] == true && mounted) {
        setState(() => _request = res['request'] is Map ? Map<String, dynamic>.from(res['request']) : null);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please tell us why you want to delete your account (at least 10 characters).')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('If an admin approves, your account will be closed and you will not be able to log in again. Any money left in your wallet will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    Map<String, dynamic> res;
    try {
      res = await _api.requestAccountDeletion(reason: reason);
    } catch (_) {
      res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['message'] ?? ''}')));
    if (res['success'] == true) {
      _reasonCtrl.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _request?['status'];
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: Colors.red.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'When an admin approves your request, your personal details are removed and you will no longer be able to log in. Records of past transactions are kept for accounting and legal reasons. Please use or withdraw your wallet balance first: any balance left when the account is closed is lost.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (status == 'pending')
                  Card(
                    color: Colors.orange.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Waiting for review. An admin will approve or reject your request. You will be notified of the result.', style: TextStyle(fontSize: 14)),
                    ),
                  )
                else ...[
                  if (status == 'rejected')
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your last request was rejected.', style: TextStyle(fontWeight: FontWeight.bold)),
                            if ((_request?['admin_note'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('${_request!['admin_note']}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (status == 'rejected') const SizedBox(height: 16),
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(labelText: tr('Why do you want to delete your account?'), border: const OutlineInputBorder(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size.fromHeight(50)),
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send deletion request'),
                  ),
                ],
              ],
            ),
    );
  }
}
