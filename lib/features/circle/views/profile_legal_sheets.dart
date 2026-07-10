import 'package:flutter/material.dart';

import 'package:memory_app/core/theme.dart';

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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: dark ? kBlack : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terms & Conditions',
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (dark ? kCream : kCharcoal).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: dark ? kCream : kCharcoal,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _termsLastUpdated,
                    style: TextStyle(
                      color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final (heading, body) in _termsSections)
                    _TermsItem(heading: heading, body: body, dark: dark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark ? kYellow : kBlack,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              color: dark ? kYellow : kBlack,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: dark
                  ? kCream.withValues(alpha: 0.8)
                  : kCharcoal.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.45,
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
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: dark ? kBlack : kYellow,
      title: Text(
        title,
        style: TextStyle(
          color: dark ? kCream : kCharcoal,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: TextStyle(
            color: dark
                ? kCream.withValues(alpha: 0.8)
                : kCharcoal.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(
              color: dark ? kYellow : kBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
