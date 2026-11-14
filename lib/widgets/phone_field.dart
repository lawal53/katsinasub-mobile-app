import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../phone_utils.dart';

/// Phone input used wherever the app asks for a number: cleans spaces / +234 automatically
/// and has a green "pick from contacts" button at the end of the field.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool showContactButton;
  final ValueChanged<String>? onChanged;
  const PhoneField({super.key, required this.controller, this.labelText, this.hintText, this.showContactButton = true, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [PhoneNumberFormatter(), LengthLimitingTextInputFormatter(15)],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        suffixIcon: showContactButton
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final n = await pickContactNumber(context);
                    if (n != null) {
                      controller.text = n;
                      controller.selection = TextSelection.collapsed(offset: n.length);
                      onChanged?.call(n);
                    }
                  },
                  child: Container(width: 40, decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_outline, color: Colors.white, size: 22)),
                ),
              )
            : null,
      ),
    );
  }
}
