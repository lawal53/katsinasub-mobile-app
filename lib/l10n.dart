import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'l10n_ha.dart';

/// App-wide language (English is the default; Hausa is chosen by the user).
/// Every [Text] in the app goes through [tr], so switching language changes
/// the whole app — the same way the website's language switcher does.
class AppLang {
  static final ValueNotifier<String> notifier = ValueNotifier<String>('en');
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_lang';

  static Future<void> load() async {
    try {
      final v = await _storage.read(key: _key);
      if (v == 'ha' || v == 'en') notifier.value = v!;
    } catch (_) {}
  }

  static Future<void> set(String code) async {
    notifier.value = code == 'ha' ? 'ha' : 'en';
    try { await _storage.write(key: _key, value: notifier.value); } catch (_) {}
  }

  static bool get isHausa => notifier.value == 'ha';
}

/// Translates an English UI string to the chosen language.
String tr(String s) {
  if (AppLang.notifier.value != 'ha') return s;
  final direct = kHausa[s];
  if (direct != null) return direct;
  // Strings with a dynamic tail, e.g. "Meter: 123" or "Hi, Aisha".
  for (final sep in const [': ', ', ', ' — ', ' (']) {
    final i = s.indexOf(sep);
    if (i > 0) {
      final head = kHausa[s.substring(0, i)];
      if (head != null) return head + s.substring(i);
    }
  }
  return s;
}

/// Drop-in replacement for Flutter's Text that translates its content and
/// re-renders instantly when the language changes.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLang.notifier,
      builder: (context, _, __) => w.Text(
        tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ),
    );
  }
}

/// Bottom sheet with the language choices (English / Hausa).
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ValueListenableBuilder<String>(
        valueListenable: AppLang.notifier,
        builder: (context, code, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: Icon(code == 'en' ? Icons.radio_button_checked : Icons.radio_button_off),
              title: const w.Text('English'),
              onTap: () { AppLang.set('en'); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(code == 'ha' ? Icons.radio_button_checked : Icons.radio_button_off),
              title: const w.Text('Hausa'),
              onTap: () { AppLang.set('ha'); Navigator.pop(ctx); },
            ),
          ],
        ),
      ),
    ),
  );
}
