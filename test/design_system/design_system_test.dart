import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/design_system/design_system.dart';

/// Pumps [child] inside just enough scaffolding to lay it out.
Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('MemoryLoading', () {
    testWidgets('the default constructor adds no padding around the spinner', (
      tester,
    ) async {
      // Regression: the inline spinner used to wrap itself in Center plus 20px
      // of vertical padding, so every button and chat bubble it sat in was
      // silently pushed apart.
      await pump(tester, const MemoryLoading(size: 18));

      expect(
        find.descendant(
          of: find.byType(MemoryLoading),
          matching: find.byType(Padding),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(MemoryLoading)), const Size(18, 18));
    });

    testWidgets('block centres the spinner and gives it room', (tester) async {
      await pump(tester, const MemoryLoading.block());

      expect(
        find.descendant(
          of: find.byType(MemoryLoading),
          matching: find.byType(Padding),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a value renders determinate progress', (tester) async {
      await pump(tester, const MemoryLoading(value: 0.4));

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.4);
    });

    testWidgets('no value spins indeterminately', (tester) async {
      await pump(tester, const MemoryLoading());

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });
  });

  group('MemoryButton', () {
    testWidgets('the loading spinner takes the button foreground', (
      tester,
    ) async {
      // Regression: the spinner had no colour, so on the accent-filled primary
      // button it drew accent-on-accent and was invisible.
      await pump(
        tester,
        const MemoryButton(
          label: 'Save',
          dark: false,
          onPressed: null,
          isLoading: true,
        ),
      );

      final spinner = tester.widget<MemoryLoading>(find.byType(MemoryLoading));
      expect(spinner.color, MemoryColors.accent);
    });

    testWidgets('a loading button does not report a press', (tester) async {
      var pressed = false;
      await pump(
        tester,
        MemoryButton(
          label: 'Save',
          dark: false,
          isLoading: true,
          onPressed: () => pressed = true,
        ),
      );

      await tester.tap(find.byType(MemoryButton));
      await tester.pump();
      expect(pressed, isFalse);
    });

    testWidgets('the text variant hugs its label rather than filling', (
      tester,
    ) async {
      await pump(
        tester,
        MemoryButton(
          label: 'Read All',
          dark: false,
          variant: MemoryButtonVariant.text,
          onPressed: () {},
        ),
      );

      final width = tester.getSize(find.byType(MemoryButton)).width;
      expect(width, lessThan(300));
    });

    testWidgets('every variant announces itself as a button', (tester) async {
      final handle = tester.ensureSemantics();
      for (final variant in MemoryButtonVariant.values) {
        await pump(
          tester,
          MemoryButton(
            label: 'Go',
            dark: false,
            variant: variant,
            onPressed: () {},
          ),
        );
        expect(
          tester.getSemantics(find.byType(MemoryButton)),
          matchesSemantics(
            label: 'Go',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
          reason: '$variant should be a button',
        );
      }
      handle.dispose();
    });
  });

  group('MemoryBadge', () {
    testWidgets('renders a bare dot when no count is given', (tester) async {
      await pump(tester, const MemoryBadge(dark: false));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the count, and collapses past nine', (tester) async {
      await pump(tester, const MemoryBadge(dark: false, count: 3));
      expect(find.text('3'), findsOneWidget);

      await pump(tester, const MemoryBadge(dark: false, count: 10));
      expect(find.text('9+'), findsOneWidget);

      await pump(tester, const MemoryBadge(dark: false, count: 250));
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('nine still reads as nine', (tester) async {
      await pump(tester, const MemoryBadge(dark: false, count: 9));
      expect(find.text('9'), findsOneWidget);
    });
  });

  group('MemoryShareButton', () {
    testWidgets('carries the brand gradient and a screen-reader label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MemoryShareButton(brand: MemoryShareBrand.whatsApp, onPressed: () {}),
      );

      expect(
        tester.getSemantics(find.byType(MemoryShareButton)),
        matchesSemantics(
          label: 'Share to WhatsApp',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('both brands lay out at the same height', (tester) async {
      // The three hand-rolled copies this replaced were 44dp and 48dp.
      final heights = <double>[];
      for (final brand in MemoryShareBrand.values) {
        await pump(
          tester,
          SizedBox(
            width: 200,
            child: MemoryShareButton(brand: brand, onPressed: () {}),
          ),
        );
        heights.add(tester.getSize(find.byType(MemoryShareButton)).height);
      }
      expect(heights, everyElement(44.0));
    });
  });

  group('MemoryGradientSurface', () {
    testWidgets('a single colour renders flat rather than throwing', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 50,
          height: 50,
          child: MemoryGradientSurface(colors: [MemoryColors.accent]),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('always runs top-left to bottom-right', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 50,
          height: 50,
          child: MemoryGradientSurface(
            colors: [MemoryColors.accent, MemoryColors.mint],
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
    });
  });

  group('MemoryIconButton', () {
    testWidgets('presents a 48dp target even for a small glyph', (
      tester,
    ) async {
      await pump(
        tester,
        MemoryIconButton(
          icon: Icons.close,
          semanticLabel: 'Close',
          iconSize: 12,
          visualSize: 20,
          onPressed: () {},
        ),
      );

      final size = tester.getSize(find.byType(MemoryIconButton));
      expect(size.width, greaterThanOrEqualTo(MemoryIconButton.minTouchTarget));
      expect(
        size.height,
        greaterThanOrEqualTo(MemoryIconButton.minTouchTarget),
      );
    });
  });

  group('type scale', () {
    test('is ten steps, strictly descending, with no duplicate size', () {
      const scale = <String, TextStyle>{
        'displayLarge': MemoryTypography.displayLarge,
        'headlineLarge': MemoryTypography.headlineLarge,
        'headlineMedium': MemoryTypography.headlineMedium,
        'titleLarge': MemoryTypography.titleLarge,
        'titleMedium': MemoryTypography.titleMedium,
        'bodyLarge': MemoryTypography.bodyLarge,
        'bodyMedium': MemoryTypography.bodyMedium,
        'bodySmall': MemoryTypography.bodySmall,
        'caption': MemoryTypography.caption,
        'overline': MemoryTypography.overline,
      };
      expect(scale, hasLength(10));

      final sizes = scale.values.map((s) => s.fontSize!).toList();
      for (var i = 1; i < sizes.length; i++) {
        expect(
          sizes[i],
          lessThan(sizes[i - 1]),
          reason: 'the scale must descend without ties',
        );
      }
    });

    test('an emoji carries no weight and a pinned line height', () {
      final e = MemoryTypography.emoji(28);
      expect(e.fontSize, 28);
      expect(e.fontWeight, isNull);
      expect(e.height, 1);
    });

    test('carries no fontFamily, so it inherits Plus Jakarta Sans', () {
      const styles = <TextStyle>[
        MemoryTypography.displayLarge,
        MemoryTypography.headlineLarge,
        MemoryTypography.headlineMedium,
        MemoryTypography.titleLarge,
        MemoryTypography.titleMedium,
        MemoryTypography.bodyLarge,
        MemoryTypography.bodyMedium,
        MemoryTypography.bodySmall,
        MemoryTypography.caption,
        MemoryTypography.overline,
        MemoryTypography.wordmark,
        MemoryTypography.mediaCaption,
        MemoryTypography.micro,
        MemoryTypography.button,
        MemoryTypography.buttonCompact,
      ];
      for (final style in styles) {
        expect(style.fontFamily, isNull);
        expect(style.color, isNull, reason: 'colour comes from the surface');
      }
    });
  });

  group('MemorySwitchTile', () {
    testWidgets('reports its state and label to a screen reader once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MemorySwitchTile(
          label: 'Push Notifications',
          value: true,
          dark: false,
          onChanged: (_) {},
        ),
      );

      // The switch keeps its own toggle action; the label merges into it.
      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, contains('Push Notifications'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'a reader must be able to flip it, not only read it',
      );
      handle.dispose();
    });

    testWidgets('a null onChanged disables the row', (tester) async {
      await pump(
        tester,
        const MemorySwitchTile(
          label: 'Locked',
          value: false,
          dark: false,
          onChanged: null,
        ),
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull);
    });
  });

  group('MemorySheetAction', () {
    testWidgets('a destructive action tints its glyph and label', (
      tester,
    ) async {
      await pump(
        tester,
        MemorySheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete message',
          dark: true,
          isDestructive: true,
          onTap: () {},
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, MemoryColors.danger);

      final text = tester.widget<Text>(find.text('Delete message'));
      expect(text.style!.color, MemoryColors.danger);
    });

    testWidgets('announces itself as a button, exactly once', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MemorySheetAction(
          icon: Icons.refresh_rounded,
          label: 'Retry sending',
          dark: true,
          onTap: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(MemorySheetAction)),
        matchesSemantics(
          label: 'Retry sending',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: false,
        ),
      );
      handle.dispose();
    });
  });

  group('MemoryInlineField', () {
    testWidgets('draws no border and no fill', (tester) async {
      await pump(
        tester,
        MemoryInlineField(
          controller: TextEditingController(),
          hint: 'Write a comment...',
          style: MemoryTypography.bodyMedium,
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.border, InputBorder.none);
      expect(field.decoration!.filled, isNot(true));
      expect(field.decoration!.hintText, 'Write a comment...');
    });

    testWidgets('the hint inherits the typed text style, faded', (
      tester,
    ) async {
      await pump(
        tester,
        MemoryInlineField(
          controller: TextEditingController(),
          hint: 'Add caption',
          style: MemoryTypography.mediaCaption.copyWith(color: Colors.white),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      final hint = field.decoration!.hintStyle!;
      expect(hint.fontSize, MemoryTypography.mediaCaption.fontSize);
      expect(hint.color!.a, closeTo(0.4, 0.01));
    });
  });

  group('MemoryAppBar', () {
    testWidgets('is transparent, flat, and toolbar-height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: MemoryAppBar(title: 'Notifications', dark: false),
          ),
        ),
      );

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, Colors.transparent);
      expect(bar.elevation, 0);
      expect(find.text('Notifications'), findsOneWidget);
    });
  });

  group('MemoryWatermark', () {
    testWidgets('is invisible to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const MemoryWatermark(size: 80, angle: -0.4, opacity: 0.02),
      );
      expect(find.bySemanticsLabel('M'), findsNothing);
      handle.dispose();
    });
  });

  group('radius scale', () {
    test('is five doubling steps, plus the pill shape', () {
      expect(MemoryRadius.xs, 4);
      expect(MemoryRadius.sm, 8);
      expect(MemoryRadius.md, 12);
      expect(MemoryRadius.lg, 16);
      expect(MemoryRadius.xl, 24);
      expect(MemoryRadius.pill, 999);
    });
  });
}
