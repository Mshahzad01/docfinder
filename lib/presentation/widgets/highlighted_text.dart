import 'package:flutter/material.dart';

/// Text with every occurrence of the search [terms] highlighted
/// (case-insensitive).
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    this.terms = const [],
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final List<String> terms;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final ranges = _ranges();
    if (ranges.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final scheme = Theme.of(context).colorScheme;
    final hit = base.copyWith(
      backgroundColor: scheme.tertiaryContainer,
      color: scheme.onTertiaryContainer,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.$1 > cursor) spans.add(TextSpan(text: text.substring(cursor, r.$1)));
      spans.add(TextSpan(text: text.substring(r.$1, r.$2), style: hit));
      cursor = r.$2;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<(int, int)> _ranges() {
    if (terms.isEmpty || text.isEmpty) return const [];
    final lower = text.toLowerCase();
    if (lower.length != text.length) return const []; // unusual Unicode: skip
    final found = <(int, int)>[];
    for (final t in terms) {
      if (t.isEmpty) continue;
      var i = lower.indexOf(t);
      while (i != -1) {
        found.add((i, i + t.length));
        i = lower.indexOf(t, i + t.length);
      }
    }
    if (found.isEmpty) return const [];
    found.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[found.first];
    for (final r in found.skip(1)) {
      final last = merged.last;
      if (r.$1 <= last.$2) {
        merged[merged.length - 1] = (last.$1, r.$2 > last.$2 ? r.$2 : last.$2);
      } else {
        merged.add(r);
      }
    }
    return merged;
  }
}
