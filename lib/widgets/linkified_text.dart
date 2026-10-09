import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows text where every http(s):// link is tappable (opens in the browser).
/// Used for notification messages, so a link an admin sends is clickable.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const LinkifiedText(this.text, {super.key, this.style});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final _urlRe = RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
      }
    }
  }

  List<InlineSpan> _spans(TextStyle base) {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in _urlRe.allMatches(text)) {
      var url = m.group(0)!;
      var end = m.end;
      // Don't swallow sentence punctuation that follows a link.
      while (url.isNotEmpty && '.,;:!?)]}'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        end--;
      }
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final rec = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: url,
        style: base.copyWith(color: Colors.blue.shade700, decoration: TextDecoration.underline),
        recognizer: rec,
      ));
      pos = end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = (widget.style ?? DefaultTextStyle.of(context).style);
    return RichText(text: TextSpan(style: base, children: _spans(base)));
  }
}
