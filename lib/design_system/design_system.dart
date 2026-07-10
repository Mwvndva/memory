/// Memory's design system.
///
/// The single source of truth for visual style. Feature code imports this
/// barrel and nothing else from `design_system/`; it never reaches for a raw
/// Material widget when a Memory component exists, and never hardcodes a
/// colour, radius, spacing value, text style or duration.
///
/// Layers:
///   foundation/ — tokens. No widgets, no behaviour.
///   components/ — Memory-branded widgets built from Material 3 primitives.
library;

export 'foundation/memory_colors.dart';
export 'foundation/memory_elevation.dart';
export 'foundation/memory_interactions.dart';
export 'foundation/memory_motion.dart';
export 'foundation/memory_radius.dart';
export 'foundation/memory_spacing.dart';
export 'foundation/memory_typography.dart';

export 'components/memory_avatar.dart';
export 'components/memory_badge.dart';
export 'components/memory_context_menu.dart';
export 'components/memory_dialog.dart';
export 'components/memory_icon_button.dart';
export 'components/memory_snack_bar.dart';
export 'components/memory_states.dart';
export 'components/memory_text_field.dart';
export 'components/memory_top_bar.dart';
export 'components/memory_bottom_sheet.dart';
export 'components/memory_brand_marks.dart';
export 'components/memory_gradient_surface.dart';
export 'components/memory_share_button.dart';
export 'components/memory_switch_tile.dart';
export 'components/memory_sheet_action.dart';
export 'components/memory_dropdown.dart';
export 'components/memory_watermark.dart';
export 'components/memory_button.dart';
export 'components/memory_card.dart';
export 'components/memory_divider.dart';
export 'components/memory_empty_state.dart';
export 'components/memory_list_tile.dart';
export 'components/memory_loading.dart';
export 'components/memory_section.dart';
export 'components/memory_section_header.dart';
