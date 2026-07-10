import 'package:flutter/material.dart';

import 'package:memory_app/design_system/design_system.dart';

class PulseRedDot extends StatefulWidget {
  const PulseRedDot({super.key});

  @override
  State<PulseRedDot> createState() => PulseRedDotState();
}

class PulseRedDotState extends State<PulseRedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MemoryDurations.pulse,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: MemoryColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
