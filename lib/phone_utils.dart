import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Cleans a phone number: removes spaces/dashes/dots/brackets and turns
/// +234 / 234 / 00234 into a leading 0 ("+2348031234567" -> "08031234567").
/// A bare "234..." only converts once it is a full international number (13+ chars),
/// so typing by hand is never interrupted.
String normalizePhone(String input) {
  var s = input.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
  if (s.startsWith('00234')) s = '+234${s.substring(5)}';
  if (s.startsWith('+234')) {
    final rest = s.substring(4);
    return rest.startsWith('0') ? rest : '0$rest';
  }
  if (s.startsWith('234') && s.length >= 13) {
    final rest = s.substring(3);
    return rest.startsWith('0') ? rest : '0$rest';
  }
  return s;
}

/// Applies [normalizePhone] live while the customer types or pastes.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = normalizePhone(newValue.text);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: cleaned.length));
  }
}

/// Opens the contact list and returns the chosen number (cleaned), or null.
/// Asks for the Contacts permission the first time; the system picker still works if declined.
Future<String?> pickContactNumber(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await FlutterContacts.requestPermission(readonly: true);
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return null;
    final numbers = contact.phones.map((p) => normalizePhone(p.number)).where((n) => n.isNotEmpty).toSet().toList();
    if (numbers.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('This contact has no phone number.')));
      return null;
    }
    if (numbers.length == 1) return numbers.first;
    if (!context.mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          for (final n in numbers) ListTile(leading: const Icon(Icons.phone), title: Text(n), onTap: () => Navigator.pop(ctx, n)),
        ]),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open your contacts.')));
    return null;
  }
}
