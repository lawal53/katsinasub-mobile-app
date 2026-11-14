import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

/// Saves a beneficiary quietly after a successful purchase / transfer.
Future<void> saveBeneficiary({required String type, required String value, String name = ''}) async {
  try {
    await ApiService().addBeneficiary(type: type, value: value, name: name);
  } catch (_) {}
}

/// "Save beneficiary" tick box + a "Saved" button that lists the customer's
/// saved people / numbers so they can pick one instead of typing it again.
/// type: 'phone' (data + airtime) or 'transfer'.
class BeneficiaryPicker extends StatefulWidget {
  final String type;
  final TextEditingController controller; // the field that receives the picked value
  final ValueNotifier<bool> saveFlag;
  final TextEditingController nameCtrl;
  const BeneficiaryPicker({super.key, required this.type, required this.controller, required this.saveFlag, required this.nameCtrl});

  @override
  State<BeneficiaryPicker> createState() => _BeneficiaryPickerState();
}

class _BeneficiaryPickerState extends State<BeneficiaryPicker> {
  Future<void> _open() async {
    final api = ApiService();
    var future = api.beneficiaries(widget.type);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('Saved Beneficiaries', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Flexible(
                  child: FutureBuilder<List<dynamic>>(
                    future: future,
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator());
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return const Padding(padding: EdgeInsets.all(30), child: Text('No saved beneficiaries yet.', style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final b = list[i] as Map;
                          final name = '${b['name'] ?? ''}'.trim();
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                            title: Text(name.isNotEmpty ? name : '${b['value']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: name.isNotEmpty ? Text('${b['value']}') : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await api.deleteBeneficiary(int.tryParse('${b['id']}') ?? 0);
                                setSheet(() => future = api.beneficiaries(widget.type));
                              },
                            ),
                            onTap: () {
                              widget.controller.text = '${b['value']}';
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.saveFlag,
      builder: (context, on, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(value: on, onChanged: (v) => widget.saveFlag.value = v ?? false),
              const Expanded(child: Text('Save beneficiary')),
              TextButton.icon(onPressed: _open, icon: const Icon(Icons.bookmarks_outlined, size: 18), label: const Text('Saved')),
            ],
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: widget.nameCtrl,
                maxLength: 40,
                decoration: InputDecoration(labelText: tr('Name (optional)'), border: const OutlineInputBorder(), isDense: true, counterText: ''),
              ),
            ),
        ],
      ),
    );
  }
}
