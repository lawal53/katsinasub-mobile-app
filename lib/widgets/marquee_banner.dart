import 'package:flutter/material.dart';

/// A red notice bar whose text glides slowly from right to left and, when it
/// reaches the end, starts again from the beginning. It has no close button:
/// it stays until the admin deletes the notice.
class MarqueeBanner extends StatefulWidget {
  final String text;
  const MarqueeBanner({super.key, required this.text});
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
    const style = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600);
    return Container(
      height: 40,
      decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final tp = TextPainter(text: TextSpan(text: widget.text, style: style), maxLines: 1, textDirection: TextDirection.ltr)..layout();
              final boxW = box.maxWidth;
              final total = boxW + tp.width;
              final ms = (total / 40 * 1000).round(); // slow: about 40 pixels a second
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
