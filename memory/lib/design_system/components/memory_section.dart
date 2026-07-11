import 'package:flutter/material.dart';

import 'memory_card.dart';
import 'memory_section_header.dart';

/// A titled group of rows: a [MemorySectionHeader] above a [MemoryCard].
///
/// The pairing is a component rather than a convention so the gap between a
/// header and its card cannot drift from one screen to the next.
class MemorySection extends StatelessWidget {
  const MemorySection({
    super.key,
    required this.title,
    required this.dark,
    required this.children,
  });

  final String title;
  final bool dark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemorySectionHeader(title: title, dark: dark),
        MemoryCard(
          dark: dark,
          child: Column(children: children),
        ),
      ],
    );
  }
}
