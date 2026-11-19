import 'package:flutter/material.dart';

enum BannerKind { notice, goodNews }

/// Scrolling banner for either a red Notice or a theme-colored Good News bar.
class MarqueeBanner extends StatefulWidget {
  final String text;
  final BannerKind kind;
  const MarqueeBanner({super.key, required this.text, this.kind = BannerKind.notice});
  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  int _ms = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGoodNews = widget.kind == BannerKind.goodNews;
    final cs = Theme.of(context).colorScheme;
    final bgColor = isGoodNews ? const Color(0xFF0B7D55) : const Color(0xFFD32F2F);
    final borderColor = isGoodNews ? cs.primary.withOpacity(0.35) : Colors.transparent;
    final icon = isGoodNews ? Icons.celebration_outlined : Icons.campaign_outlined;
    const style = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: isGoodNews ? Border.all(color: borderColor) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final tp = TextPainter(text: TextSpan(text: widget.text, style: style), maxLines: 1, textDirection: TextDirection.ltr)..layout();
              final boxW = box.maxWidth;
              final total = boxW + tp.width;
              final ms = (total / 40 * 1000).round();
              if (ms != _ms) {
                _ms = ms;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _c.duration = Duration(milliseconds: ms);
                  _c.repeat();
                });
              }
              return ClipRect(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) => Transform.translate(offset: Offset(boxW - _c.value * total, 0), child: child),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: Text(widget.text, maxLines: 1, softWrap: false, style: style),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
