import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/realtime/realtime_providers.dart';
import 'package:memory_app/design_system/design_system.dart';

class DevDiagnosticsView extends ConsumerStatefulWidget {
  const DevDiagnosticsView({super.key});

  @override
  ConsumerState<DevDiagnosticsView> createState() => _DevDiagnosticsViewState();
}

class _DevDiagnosticsViewState extends ConsumerState<DevDiagnosticsView> {
  bool _loading = false;
  Map<String, dynamic> _lastRaw = {};

  Future<void> _refreshAll() async {
    setState(() => _loading = true);

    final dio = ref.read(apiClientProvider);
    final circlesNotifier = ref.read(circlesProvider.notifier);

    final results = <String, dynamic>{};

    try {
      final pending = await dio.get('/circles/requests/pending');
      results['pending_requests'] = pending.data;
    } catch (e) {
      results['pending_requests_error'] = e.toString();
    }

    try {
      final members = await dio.get('/circles/members');
      results['members'] = members.data;
    } catch (e) {
      results['members_error'] = e.toString();
    }

    try {
      await circlesNotifier.fetchCircle();
      final cached = ref.read(circlesProvider);
      results['repo_circle_cached'] = cached
          .map(
            (m) => {
              'id': m.id,
              'username': m.username,
              'firstName': m.firstName,
              'lastName': m.lastName,
              'avatarUrl': m.avatarUrl,
            },
          )
          .toList();
    } catch (e) {
      results['repo_circle_error'] = e.toString();
    }

    final chatState = ref.read(chatProvider);
    results['chat_state'] = {
      'unreadNotifications': chatState.unreadNotifications,
      'messagesByContact': chatState.messagesByContact.map(
        (k, v) => MapEntry(
          k,
          v
              .map(
                (m) => {
                  'id': m.id,
                  'sender': m.sender,
                  'text': m.text,
                  'timestamp': m.timestamp.toIso8601String(),
                  'isMine': m.isMine,
                },
              )
              .toList(),
        ),
      ),
    };

    final coordinator = ref.read(realtimeCoordinatorProvider);
    results['realtime_diagnostics'] = {
      'connectionState': coordinator.connectionState.toString(),
      'reconnectAttempts': coordinator.reconnectAttempts,
      'heartbeatFailures': coordinator.heartbeatFailures,
      'lastConnectedAt': coordinator.lastConnectedAt?.toIso8601String(),
      'recentDisconnectReasons': coordinator.recentDisconnectReasons,
    };

    setState(() {
      _lastRaw = results;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MemoryAppBar(
        title: 'Dev Diagnostics',
        dark: Theme.of(context).brightness == Brightness.dark,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: MemorySpacing.gutter),
              child: Center(child: MemoryLoading()),
            )
          else
            MemoryIconButton(
              icon: Icons.refresh,
              semanticLabel: 'Refresh diagnostics',
              onPressed: _refreshAll,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MemorySpacing.xl),
        child: SelectableText(
          _lastRaw.isEmpty ? 'No data yet' : _prettyJson(_lastRaw),
        ),
      ),
    );
  }

  String _prettyJson(Object? o) {
    try {
      return const JsonEncoder.withIndent('  ').convert(o);
    } catch (_) {
      return o?.toString() ?? '';
    }
  }
}
