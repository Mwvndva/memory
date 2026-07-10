import 'package:flutter/material.dart';

import '../foundation/memory_colors.dart';
import '../foundation/memory_interactions.dart';
import '../foundation/memory_radius.dart';
import '../foundation/memory_spacing.dart';
import '../foundation/memory_typography.dart';

/// A third-party destination a memory or invite can be shared to.
enum MemoryShareBrand {
  instagram(
    label: 'Instagram',
    icon: Icons.camera_alt_rounded,
    gradient: MemoryColors.instagramGradient,
  ),
  whatsApp(
    label: 'WhatsApp',
    icon: Icons.chat_bubble_rounded,
    gradient: MemoryColors.whatsAppGradient,
  );

  const MemoryShareBrand({
    required this.label,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;

  /// The pill's glow, taken from the brand's own leading colour.
  Color get _glow => gradient.first.withValues(alpha: 0.35);
}

/// A brand-coloured share pill.
///
/// This is the one place Memory renders someone else's colours, so the brand
/// gradient and white label are deliberate rather than an escape hatch. It
/// replaces three hand-rolled copies that had drifted to different heights,
/// icon sizes, and shadows, and none of which announced themselves as buttons
/// to a screen reader.
class MemoryShareButton extends StatelessWidget {
  const MemoryShareButton({
    super.key,
    required this.brand,
    required this.onPressed,
  });

  final MemoryShareBrand brand;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Share to ${brand.label}',
      child: BouncyTap(
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: brand.gradient),
            borderRadius: MemoryRadius.allPill,
            boxShadow: [
              BoxShadow(
                color: brand._glow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(brand.icon, color: Colors.white, size: 16),
                const SizedBox(width: MemorySpacing.md),
                Text(
                  brand.label,
                  style: MemoryTypography.buttonCompact.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
