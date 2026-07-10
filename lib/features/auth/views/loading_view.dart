import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/auth/auth.dart';

class LoadingView extends ConsumerStatefulWidget {
  const LoadingView({super.key});

  @override
  ConsumerState<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends ConsumerState<LoadingView> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!session.isRestoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(session.isAuthenticated ? '/capture' : '/login');
        }
      });
    }

    return Scaffold(
      backgroundColor: MemoryColors.accent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/memory-logo.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: MemoryLoading(size: 24, color: MemoryColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
