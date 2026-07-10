import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/design_system/design_system.dart';
import '../circle_state_manager.dart';
import '../widgets/circle_list_tiles.dart';

class CircleChatListView extends ConsumerWidget {
  const CircleChatListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(isDarkProvider);
    final circleMembers = ref.watch(
      circleStateManagerProvider.select((s) => s.circles),
    );
    final pendingRequests = ref.watch(
      circleStateManagerProvider.select((s) => s.pendingRequests),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          topInset + 16,
          20,
          18 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: _softBackground(dark),
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => context.go('/capture'),
                      color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Your circle',
                          style: TextStyle(
                            color: dark
                                ? MemoryColors.cream
                                : MemoryColors.charcoal,
                            fontSize: 30,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (pendingRequests.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: 8,
                            top: 4,
                          ),
                          child: Text(
                            'SHARE REQUESTS',
                            style: TextStyle(
                              color: dark
                                  ? const Color(0xFFC9B8AA)
                                  : const Color(0xFF776B62),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...pendingRequests.map(
                          (req) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              // Open the chat/inbox for this requester (thread placeholder)
                              context.push('/chat/${req.username}');
                            },
                            child: RequestRow(req: req, dark: dark),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (circleMembers.isEmpty && pendingRequests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: MemoryEmptyState(
                            icon: Icons.people_alt_rounded,
                            title: 'No one is in your circle yet.',
                            message:
                                'Open your profile to add someone and start sharing.',
                            dark: dark,
                          ),
                        )
                      else ...[
                        if (circleMembers.isNotEmpty)
                          ...circleMembers.map(
                            (member) => ChatRow(member: member, dark: dark),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _softBackground(bool dark) => BoxDecoration(
    gradient: LinearGradient(
      colors: dark
          ? const [MemoryColors.ink, Color(0xFF171717)]
          : const [MemoryColors.accent, MemoryColors.accent],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
  );
}
