import 'package:flutter/material.dart';

import 'package:memory_app/design_system/design_system.dart';

const String _termsLastUpdated = 'Last Updated: June 2026';

const List<(String heading, String body)> _termsSections = [
  (
    '1. Welcome to Memory',
    'Memory ("we", "us", or "our") provides a private daily social sharing platform for intimate circles. By creating an account or using the Memory app, you agree to comply with and be bound by these Terms & Conditions and all applicable laws of the Republic of Kenya.',
  ),
  (
    '2. Privacy & Consent (Kenya Data Protection Act, 2019)',
    'Your privacy is critical to us. By registering an account, you explicitly consent to the collection, storage, and processing of your personal data—including your name, email, phone number, and uploaded media files (memories). All personal data is processed in strict compliance with the Kenya Data Protection Act, 2019 and registration guidelines set by the Office of the Data Protection Commissioner (ODPC). We do not sell or share your personal data with third-party advertising companies.',
  ),
  (
    '3. User-Generated Content & Liabilities (Cybercrimes Act, 2018)',
    'You are solely responsible for the video memories and captions you post to your circle. Under the Computer Misuse and Cybercrimes Act, 2018 of Kenya, it is a criminal offense to upload or share content that is pornographic, hateful, harassing, defamatory, or infringes on another person\'s copyright. We reserve the right to suspend or delete your account immediately and report violations to relevant authorities if illegal or prohibited content is detected.',
  ),
  (
    '4. Account Security',
    'You are responsible for safeguarding your password and account details. You agree to notify us immediately of any unauthorized use or security breach of your account.',
  ),
  (
    '5. Limitation of Liability',
    'The Memory app is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, or punitive damages arising from your use of the app, service disruptions, or unauthorized access to user data.',
  ),
  (
    '6. Dispute Resolution & Governing Law',
    'These terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes, claims, or controversies arising out of or relating to these terms shall be subject to the exclusive jurisdiction of the competent courts in Nairobi, Kenya.',
  ),
];

/// Full-height sheet listing the Terms & Conditions.
void showFullTermsSheet(BuildContext context, bool dark) {
  MemoryBottomSheet.show(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TermsSheet(dark: dark),
  );
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      margin: const EdgeInsets.fromLTRB(
        MemorySpacing.sheet,
        0,
        MemorySpacing.sheet,
        MemorySpacing.sheet,
      ),
      padding: const EdgeInsets.fromLTRB(
        MemorySpacing.section,
        MemorySpacing.gutter,
        MemorySpacing.section,
        MemorySpacing.section,
      ),
      decoration: BoxDecoration(
        color: MemoryColors.surface(dark),
        borderRadius: BorderRadius.circular(MemoryRadius.xl),
        boxShadow: MemoryShadows.overlay(dark),
      ),
      child: Column(
        children: [
          // Grab handle.
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: MemorySpacing.gutter),
            decoration: BoxDecoration(
              color: MemoryColors.hairline(dark, alpha: 0.15),
              borderRadius: MemoryRadius.allPill,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terms & Conditions',
                style: MemoryTypography.onSurface(
                  MemoryTypography.headlineMedium.copyWith(height: 1.0),
                  dark,
                ),
              ),
              MemoryIconButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
                semanticLabel: 'Close',
                iconSize: 18,
                visualSize: 30,
                filled: true,
                background: MemoryColors.foregroundOn(
                  dark,
                ).withValues(alpha: MemoryColors.alphaBorder),
                color: MemoryColors.foregroundOn(dark),
              ),
            ],
          ),
          const SizedBox(height: MemorySpacing.sheet),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _termsLastUpdated,
                    style: MemoryTypography.mutedOnSurface(
                      MemoryTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      dark,
                      alpha: 0.6,
                    ),
                  ),
                  const SizedBox(height: MemorySpacing.xxl),
                  for (final (heading, body) in _termsSections)
                    _TermsItem(heading: heading, body: body, dark: dark),
                ],
              ),
            ),
          ),
          const SizedBox(height: MemorySpacing.gutter),
          MemoryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
            dark: dark,
            foreground: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _TermsItem extends StatelessWidget {
  const _TermsItem({
    required this.heading,
    required this.body,
    required this.dark,
  });

  final String heading;
  final String body;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MemorySpacing.sheet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: MemoryTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: dark ? MemoryColors.accent : MemoryColors.ink,
            ),
          ),
          const SizedBox(height: MemorySpacing.sm),
          Text(
            body,
            style: MemoryTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: MemoryColors.foregroundOn(
                dark,
              ).withValues(alpha: MemoryColors.alphaSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple scrollable text dialog, used for the privacy policy.
void showPolicyDialog(
  BuildContext context,
  String title,
  String content,
  bool dark,
) {
  MemoryDialog.show(
    context: context,
    builder: (ctx) => MemoryDialog(
      title: title,
      dark: dark,
      content: SingleChildScrollView(
        child: Text(
          content,
          style: MemoryTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: MemoryColors.foregroundOn(
              dark,
            ).withValues(alpha: MemoryColors.alphaSecondary),
          ),
        ),
      ),
      actions: [
        MemoryDialogAction(
          label: 'Close',
          isPrimary: true,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}
