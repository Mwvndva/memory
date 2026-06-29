import 'dart:collection';
import 'package:flutter/foundation.dart';

enum TransactionStatus { pending, committed, rolledBack }

class OptimisticTransaction {
  final String id;
  final String memoryId;
  final String actionType; // 'like' | 'reaction'
  final Object? originalValue; // E.g., boolean, map, or snapshot
  final Object? optimisticValue;
  final TransactionStatus status;
  final DateTime timestamp;

  OptimisticTransaction({
    required this.id,
    required this.memoryId,
    required this.actionType,
    required this.originalValue,
    required this.optimisticValue,
    this.status = TransactionStatus.pending,
    required this.timestamp,
  });

  OptimisticTransaction copyWith({
    TransactionStatus? status,
  }) {
    return OptimisticTransaction(
      id: id,
      memoryId: memoryId,
      actionType: actionType,
      originalValue: originalValue,
      optimisticValue: optimisticValue,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }
}

class OptimisticTransactionManager {
  final Map<String, List<OptimisticTransaction>> _transactions = {};

  /// Checks if there's any pending transaction for [memoryId] and [actionType].
  bool hasPending(String memoryId, String actionType) {
    final list = _transactions[memoryId];
    if (list == null) return false;
    return list.any((t) => t.actionType == actionType && t.status == TransactionStatus.pending);
  }

  /// Registers a new pending transaction.
  void register(OptimisticTransaction tx) {
    _transactions.putIfAbsent(tx.memoryId, () => []).add(tx);
  }

  /// Resolves the transaction by updating its status and cleaning up completed ones.
  void resolve(String memoryId, String txId, TransactionStatus finalStatus) {
    final list = _transactions[memoryId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == txId) {
          list[i] = list[i].copyWith(status: finalStatus);
          break;
        }
      }
      // Cleanup completed (non-pending) transactions periodically to prevent leaks
      list.removeWhere((t) => t.status != TransactionStatus.pending && DateTime.now().difference(t.timestamp).inSeconds > 10);
    }
  }

  /// Get pending transaction count for testing or validation.
  int get pendingCount {
    return _transactions.values.fold(0, (sum, list) => sum + list.where((t) => t.status == TransactionStatus.pending).length);
  }
}
