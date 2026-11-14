import 'package:flutter/material.dart';
import '../l10n.dart' as l;

/// Shared building blocks for the step-by-step purchase screens
/// (Data, Airtime, Cable, Electricity, Exam): big service cards ->
/// plan-type chips -> plan cards -> phone / PIN / buy button.
/// Same look as the website's purchase pages.

const _brandColors = <String, List<int>>{
  'MTN': [0xFFFFCC00, 0xFF111111],
  'GLO': [0xFF1BA345, 0xFFFFFFFF],
  'AIRTEL': [0xFFE40000, 0xFFFFFFFF],
  '9MOBILE': [0xFF006B3F, 0xFFFFFFFF],
  'VITEL': [0xFF1F3A93, 0xFFFFFFFF],
  'GOTV': [0xFFE2231A, 0xFFFFFFFF],
  'DSTV': [0xFF0A8AD1, 0xFFFFFFFF],
  'STARTIME': [0xFFF7941D, 0xFFFFFFFF],
  'WAEC': [0xFF1F2A6B, 0xFFFFFFFF],
  'NECO': [0xFF2E7D32, 0xFFFFFFFF],
  'NABTEB': [0xFF0E7C86, 0xFFFFFFFF],
  'JAMB': [0xFF0B6B3A, 0xFFFFFFFF],
};

class ServiceBadge extends StatelessWidget {
  final String name;
  final double size;
  const ServiceBadge(this.name, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final key = name.trim().toUpperCase();
    List<int>? c = _brandColors[key];
    if (c == null) {
      for (final e in _brandColors.entries) {
        if (key.startsWith(e.key)) { c = e.value; break; }
      }
    }
    Color bg, fg;
    if (c != null) {
      bg = Color(c[0]);
      fg = Color(c[1]);
    } else {
      var h = 0;
      for (final u in key.codeUnits) { h = (h * 31 + u) % 360; }
      bg = HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.38).toColor();
      fg = Colors.white;
    }
    final words = name.trim().split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).toList();
    String txt;
    if (name.trim().length <= 4 || words.length < 2) {
      txt = name.trim().toUpperCase();
      if (txt.length > 4) txt = txt.substring(0, 4);
    } else {
      txt = (words[0][0] + words[1][0]).toUpperCase();
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(txt, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.27)),
    );
  }
}

const _green = Color(0xFF00A859);

/// Two-column grid of big selectable cards (network / provider / disco / exam).
class ServiceGrid extends StatelessWidget {
  final List<String> names;
  final Map<String, String> subtitles; // optional second line, e.g. price
  final String? selected;
  final void Function(String) onPick;
  const ServiceGrid({super.key, required this.names, required this.selected, required this.onPick, this.subtitles = const {}});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 14) / 2;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final n in names)
            SizedBox(
              width: w,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onPick(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: selected == n ? const Color(0xFFF1FAF5) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected == n ? _green : Colors.grey.shade300, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ServiceBadge(n),
                      const SizedBox(height: 10),
                      Text(n, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, color: selected == n ? Colors.green.shade900 : null)),
                      if (subtitles[n] != null)
                        Text(subtitles[n]!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Rounded pill chips (plan type, meter type).
class TypeChips extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final void Function(String) onPick;
  const TypeChips({super.key, required this.items, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onPick(it),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: selected == it ? _green : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected == it ? _green : Colors.grey.shade300, width: 1.5),
              ),
              child: Text(it.isEmpty ? it : it[0].toUpperCase() + it.substring(1), style: TextStyle(fontWeight: FontWeight.w700, color: selected == it ? Colors.white : null)),
            ),
          ),
      ],
    );
  }
}

/// One selectable plan / package card: name on top, green price below.
class PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  const PlanCard({super.key, required this.title, required this.price, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1FAF5) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _green : Colors.grey.shade300, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 6),
              Text(price, style: const TextStyle(fontWeight: FontWeight.w800, color: _green, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small section label ("Select Network", "Plan Type", ...).
class StepLabel extends StatelessWidget {
  final String text;
  const StepLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: l.Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54)),
      );
}
